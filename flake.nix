{
  description = "Single-host Quickshell desktop action center";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nm-daemon = {
      # Use the portable sibling layout until the current API history is published.
      url = "git+file:../nm-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bt-daemon = {
      # Use the portable sibling layout until the initial API history is published.
      url = "git+file:../bt-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    clip-daemon = {
      # Use the sibling daemon during clipboard UI development.
      url = "git+file:../clip-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    app-daemon = {
      # Use the sibling daemon during launcher development.
      url = "git+file:../app-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bar-daemon = {
      # Use the sibling daemon during top-bar development.
      url = "git+file:../bar-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      homeManagerModules = {
        default = import ./nix/home-manager.nix self;
        shelllist = self.homeManagerModules.default;
      };

      nixosModules = {
        default = import ./nix/nixos.nix self;
        shelllist = self.nixosModules.default;
      };

      packages = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
          clipDaemon = inputs."clip-daemon".packages.${system}.default;
          appDaemon = inputs."app-daemon".packages.${system}.default;
          barDaemon = inputs."bar-daemon".packages.${system}.default;
          nmDaemonConnectParityProbe = inputs."nm-daemon".packages.${system}.connectParityProbe;
          mkMeta = description: mainProgram: {
            inherit description mainProgram;
            platforms = pkgs.lib.platforms.linux;
          };
        in
        {
          connectParityProbe = nmDaemonConnectParityProbe;

          shelllistApplication = pkgs.writeShellApplication {
            name = "shelllist";
            meta = mkMeta "Single-host Shelllist desktop action center" "shelllist";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.jq
              pkgs.quickshell
              pkgs.qrencode
              pkgs.kdePackages.qrca
              self.packages.${system}.captivePortalBrowser
              nmDaemon
              btDaemon
              clipDaemon
              appDaemon
              barDaemon
              pkgs.pavucontrol
              pkgs.ghostty
            ];
            text = ''
              config_path=${self.packages.${system}.shelllistConfig}/share/shelllist/shell
              export QML_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

              usage() {
                cat <<'EOF'
              Usage: shelllist [COMMAND]

              Surface commands:
                shelllist                         Toggle Applications
                shelllist <surface> [open|toggle] Open or toggle a surface
                shelllist open [surface]          Open a surface (default: applications)
                shelllist toggle [surface]        Toggle a surface (default: applications)
                shelllist floating [surface]      Run a one-shot floating host
                shelllist hide                    Hide the active surface
                shelllist quit                    Stop the resident host
                shelllist status                  Print host status as JSON
                shelllist list                    List surfaces as JSON
                shelllist daemon                  Ensure the resident host is running
                shelllist run                     Run the resident host in the foreground

              Surfaces: applications, wifi, bluetooth, clipboard, activity

              Clipboard settings:
                shelllist clipboard pause
                shelllist clipboard private
                shelllist clipboard resume
                shelllist clipboard kept COUNT
              EOF
              }

              valid_surface() {
                case "$1" in
                  applications|wifi|bluetooth|clipboard|activity) return 0 ;;
                  *) return 1 ;;
                esac
              }

              popover_ipc() {
                quickshell ipc --path "$config_path" --newest call shelllist "$@"
              }

              current_daemon_running() {
                quickshell list --all 2>/dev/null \
                  | awk -v expected="$config_path/shell.qml" '
                      /^  Config path:/ {
                        path = $0
                        sub(/^  Config path: /, "", path)
                        if (path == expected) found = 1
                      }
                      END { exit(found ? 0 : 1) }
                    '
              }

              stop_stale_hosts() {
                quickshell list --all 2>/dev/null \
                  | awk '
                      /^Instance / { pid = ""; shelllist = 0 }
                      /Process ID:/ { pid = $3 }
                      /Config path: .*share\/shelllist\/(shell|wifi|bluetooth|clipboard|launcher|activity)\/shell.qml/ { shelllist = 1 }
                      shelllist && pid != "" { print pid; pid = ""; shelllist = 0 }
                    ' \
                  | while read -r pid; do
                      [ -n "$pid" ] && quickshell kill --pid "$pid" >/dev/null 2>&1 || true
                    done \
                  || true
              }

              ensure_daemon() {
                if current_daemon_running && popover_ipc ping >/dev/null 2>&1; then
                  return 0
                fi

                stop_stale_hosts
                SHELLLIST_MODE=popover quickshell --path "$config_path" --daemonize --no-duplicate >/dev/null 2>&1 || true
                attempts=0
                while [ "$attempts" -lt 30 ]; do
                  if popover_ipc ping >/dev/null 2>&1; then
                    return 0
                  fi
                  attempts=$((attempts + 1))
                  sleep 0.05
                done
                echo "Shelllist host did not become ready" >&2
                return 1
              }

              surface_call() {
                action=$1
                surface=$2
                valid_surface "$surface" || {
                  echo "Unknown Shelllist surface: $surface" >&2
                  return 2
                }
                ensure_daemon || return 1
                result=$(popover_ipc "$action" "$surface")
                [ "$result" = ok ] || {
                  echo "Shelllist rejected $action for $surface: $result" >&2
                  return 1
                }
              }

              clip_call() {
                request=$1
                response=
                coproc CLIP_CLIENT { clip-daemon client; }
                client_out=''${CLIP_CLIENT[0]}
                client_in=''${CLIP_CLIENT[1]}
                client_pid=$CLIP_CLIENT_PID
                printf '%s\n' "$request" >&"$client_in"
                while IFS= read -r line <&"$client_out"; do
                  if printf '%s\n' "$line" | jq -e '.kind == "response" and .id == "shelllist-cli"' >/dev/null; then
                    response=$line
                    break
                  fi
                done
                printf '%s\n' '{"op":"shutdown","id":"shelllist-cli-shutdown"}' >&"$client_in" || true
                while IFS= read -r line <&"$client_out"; do
                  if printf '%s\n' "$line" | jq -e '.kind == "response" and .id == "shelllist-cli-shutdown"' >/dev/null; then
                    break
                  fi
                done
                wait "$client_pid" || true

                if [ -z "$response" ]; then
                  echo "clip-daemon did not return a response" >&2
                  return 1
                fi
                if ! printf '%s\n' "$response" | jq -e '.ok == true and .response.ok == true' >/dev/null; then
                  printf '%s\n' "$response" | jq -r '.response.error.message // .error // "Clipboard setting update failed"' >&2
                  return 1
                fi
              }

              clipboard_setting() {
                setting=$1
                case "$setting" in
                  pause|private|resume)
                    paused=true
                    private=false
                    [ "$setting" = private ] && private=true
                    [ "$setting" = resume ] && paused=false
                    request=$(jq -cn --argjson paused "$paused" --argjson private "$private" \
                      '{op:"call", id:"shelllist-cli", method:"clipboard.capture.setPaused", params:{paused:$paused, private_mode:$private}}')
                    clip_call "$request"
                    ;;
                  kept)
                    count=''${2:-}
                    case "$count" in
                      ""|*[!0-9]*) echo "Clipboard retention must be a non-negative integer" >&2; return 2 ;;
                    esac
                    request=$(jq -cn --argjson kept "$count" \
                      '{op:"call", id:"shelllist-cli", method:"clipboard.settings.update", params:{max_entries:$kept}}')
                    clip_call "$request"
                    ;;
                  *) return 2 ;;
                esac
              }

              command=''${1:-}
              case "$command" in
                "") surface_call toggle applications ;;
                -h|--help|help) usage ;;
                daemon) [ "$#" -eq 1 ] || { usage >&2; exit 2; }; ensure_daemon ;;
                run)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  stop_stale_hosts
                  SHELLLIST_MODE=popover exec quickshell --path "$config_path" --no-duplicate
                  ;;
                open|toggle)
                  surface=''${2:-applications}
                  [ "$#" -le 2 ] || { usage >&2; exit 2; }
                  surface_call "$command" "$surface"
                  ;;
                hide)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  if current_daemon_running; then popover_ipc hide >/dev/null; fi
                  ;;
                quit)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  if current_daemon_running; then popover_ipc quit >/dev/null; fi
                  ;;
                status)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  if current_daemon_running && popover_ipc ping >/dev/null 2>&1; then
                    popover_ipc status
                  else
                    printf '%s\n' '{"running":false,"visible":false}'
                  fi
                  ;;
                list)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  ensure_daemon && popover_ipc listSurfaces
                  ;;
                floating)
                  surface=''${2:-applications}
                  [ "$#" -le 2 ] || { usage >&2; exit 2; }
                  valid_surface "$surface" || { echo "Unknown Shelllist surface: $surface" >&2; exit 2; }
                  if current_daemon_running; then
                    echo "Run 'shelllist quit' before starting floating mode" >&2
                    exit 1
                  fi
                  SHELLLIST_INITIAL_SURFACE="$surface" SHELLLIST_MODE=floating \
                    exec quickshell --path "$config_path"
                  ;;
                clipboard)
                  operation=''${2:-toggle}
                  case "$operation" in
                    pause|private|resume)
                      [ "$#" -eq 2 ] || { usage >&2; exit 2; }
                      clipboard_setting "$operation"
                      ;;
                    kept)
                      [ "$#" -eq 3 ] || { usage >&2; exit 2; }
                      clipboard_setting kept "$3"
                      ;;
                    open|toggle)
                      [ "$#" -le 2 ] || { usage >&2; exit 2; }
                      surface_call "$operation" clipboard
                      ;;
                    *) usage >&2; exit 2 ;;
                  esac
                  ;;
                applications|wifi|bluetooth|activity)
                  action=''${2:-toggle}
                  [ "$#" -le 2 ] || { usage >&2; exit 2; }
                  case "$action" in open|toggle) surface_call "$action" "$command" ;; *) usage >&2; exit 2 ;; esac
                  ;;
                *) usage >&2; exit 2 ;;
              esac
            '';
          };

          default = pkgs.symlinkJoin {
            name = "shelllist";
            paths = [ self.packages.${system}.shelllistApplication barDaemon ];
            meta = mkMeta "Single-host Shelllist desktop action center" "shelllist";
          };

          captivePortalBrowser = pkgs.writeShellApplication {
            name = "shelllist-captive-portal";
            meta = mkMeta "Open browser pages that trigger captive portal login flows" "shelllist-captive-portal";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.hyprland
              pkgs.jq
              pkgs.util-linux
            ];
            text = ''
              started_ms=$(date +%s%3N)
              state_dir="''${XDG_RUNTIME_DIR:-/tmp}/shelllist-captive-portal"
              profile_dir="$state_dir/browser-profile"
              episode_file="$state_dir/automatic-episode"
              fallback_index_file="$state_dir/fallback-index"
              lock_file="$state_dir/lock"
              window_class="shelllist-captive-portal"
              mkdir -p "$profile_dir"

              mode=manual
              trigger=manual
              ssid=
              identity=
              connectivity=unknown
              request_id=
              episode=
              workspace=
              fallback=0
              portal_url="http://neverssl.com/"

              require_value() {
                if [ "$#" -lt 2 ]; then
                  echo "Missing value for $1" >&2
                  exit 2
                fi
              }

              while [ "$#" -gt 0 ]; do
                case "$1" in
                  --automatic) mode=automatic ;;
                  --manual) mode=manual ;;
                  --fallback) fallback=1 ;;
                  --trigger) require_value "$@"; trigger=$2; shift ;;
                  --ssid) require_value "$@"; ssid=$2; shift ;;
                  --identity) require_value "$@"; identity=$2; shift ;;
                  --connectivity) require_value "$@"; connectivity=$2; shift ;;
                  --request-id) require_value "$@"; request_id=$2; shift ;;
                  --episode) require_value "$@"; episode=$2; shift ;;
                  --workspace) require_value "$@"; workspace=$2; shift ;;
                  *) echo "Unknown option: $1" >&2; exit 2 ;;
                esac
                shift
              done

              if [ "$mode" = automatic ] && [ -z "$episode" ]; then
                echo "Automatic portal launches require --episode" >&2
                exit 2
              fi

              exec 9>"$lock_file"
              flock -x 9

              if [ "$fallback" -eq 1 ]; then
                fallback_index=0
                if [ -f "$fallback_index_file" ]; then
                  fallback_index=$(cat "$fallback_index_file")
                fi
                case "$fallback_index" in
                  0|1|2) ;;
                  *) fallback_index=0 ;;
                esac
                case "$fallback_index" in
                  0) portal_url="http://captive.apple.com/hotspot-detect.html" ;;
                  1) portal_url="http://www.msftconnecttest.com/connecttest.txt" ;;
                  *) portal_url="http://nmcheck.gnome.org/check_network_status.txt"; fallback_index=2 ;;
                esac
                printf '%s\n' $(((fallback_index + 1) % 3)) > "$fallback_index_file"
              fi

              if [ -z "$workspace" ] && command -v hyprctl >/dev/null 2>&1; then
                workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' || true)
              fi

              portal_client() {
                hyprctl clients -j 2>/dev/null \
                  | jq -c --arg class "$window_class" 'first(.[] | select((.class // "") == $class or (.initialClass // "") == $class)) // empty' \
                  || true
              }

              place_and_focus() {
                case "$workspace" in
                  "") ;;
                  *[!A-Za-z0-9_.:+-]*) workspace= ;;
                  *)
                    hyprctl dispatch "hl.dsp.window.move({ workspace = '$workspace', follow = false, window = 'class:^($window_class)$' })" >/dev/null 2>&1 \
                      || hyprctl dispatch movetoworkspacesilent "$workspace,class:^($window_class)$" >/dev/null 2>&1 \
                      || true
                    ;;
                esac
                hyprctl dispatch "hl.dsp.focus({ window = 'class:^($window_class)$' })" >/dev/null 2>&1 \
                  || hyprctl dispatch focuswindow "class:^($window_class)$" >/dev/null 2>&1 \
                  || true
              }

              log_event() {
                decision=$1
                browser_pid="''${2:-}"
                window_title="''${3:-}"
                event_ms=$(date +%s%3N)
                helper_elapsed_ms=$((event_ms - started_ms))
                jq -cn \
                  --arg decision "$decision" \
                  --arg trigger "$trigger" \
                  --arg ssid "$ssid" \
                  --arg identity "$identity" \
                  --arg connectivity "$connectivity" \
                  --arg request_id "$request_id" \
                  --arg episode "$episode" \
                  --arg workspace "$workspace" \
                  --arg browser_pid "$browser_pid" \
                  --arg window_title "$window_title" \
                  --arg url "$portal_url" \
                  --argjson helper_elapsed_ms "$helper_elapsed_ms" \
                  '{decision:$decision,trigger:$trigger,ssid:$ssid,identity:$identity,connectivity:$connectivity,request_id:$request_id,episode:$episode,workspace:$workspace,browser_pid:$browser_pid,url:$url,window_title:$window_title,helper_elapsed_ms:$helper_elapsed_ms}' \
                  | logger -t shelllist-captive-portal
              }

              existing_client=$(portal_client)
              if [ -n "$existing_client" ]; then
                place_and_focus
                existing_title=$(printf '%s' "$existing_client" | jq -r '.title // empty')
                log_event focus-existing "" "$existing_title"
                exit 0
              fi

              if [ "$mode" = automatic ] && [ -f "$episode_file" ] && [ "$(cat "$episode_file")" = "$episode" ]; then
                log_event deduplicated-episode
                exit 0
              fi

              browser=
              for candidate in google-chrome-stable google-chrome chromium; do
                if command -v "$candidate" >/dev/null 2>&1; then
                  browser=$candidate
                  break
                fi
              done

              if [ -z "$browser" ]; then
                echo "No supported browser found for captive portal" >&2
                log_event browser-unavailable
                exit 1
              fi

              "$browser" \
                --user-data-dir="$profile_dir" \
                --class="$window_class" \
                --ozone-platform=x11 \
                --no-first-run \
                --no-default-browser-check \
                --disable-search-engine-choice-screen \
                --new-window \
                --disable-extensions \
                --disable-background-mode \
                --disable-quic \
                --disable-features=HttpsUpgrades,HttpsFirstBalancedModeAutoEnable,HttpsFirstModeV2,DnsOverHttpsUpgrade \
                --no-proxy-server \
                --app="$portal_url" \
                >/dev/null 2>&1 &
              browser_pid=$!

              if [ "$mode" = automatic ]; then
                printf '%s\n' "$episode" > "$episode_file"
              fi
              log_event launched "$browser_pid"

              attempts=0
              while [ "$attempts" -lt 20 ]; do
                observed_client=$(portal_client)
                if [ -n "$observed_client" ]; then
                  place_and_focus
                  observed_title=$(printf '%s' "$observed_client" | jq -r '.title // empty')
                  log_event placed-and-focused "$browser_pid" "$observed_title"
                  exit 0
                fi
                attempts=$((attempts + 1))
                sleep 0.1
              done

              log_event window-not-observed "$browser_pid"
            '';
          };

          shelllistConfig = pkgs.stdenvNoCC.mkDerivation {
            pname = "shelllist-config";
            version = "0.2.0";
            src = ./.;
            meta = {
              description = "Shared QML configuration for Shelllist applications";
              platforms = pkgs.lib.platforms.linux;
            };
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/shelllist
              cp -r shell bar wifi bluetooth clipboard launcher activity qml $out/share/shelllist/
              runHook postInstall
            '';
          };
        });

      checks = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
          clipDaemon = inputs."clip-daemon".packages.${system}.default;
          appDaemon = inputs."app-daemon".packages.${system}.default;
          barDaemon = inputs."bar-daemon".packages.${system}.default;
        in
        {
          appDaemonContract = pkgs.runCommand "shelllist-app-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-app-api-contract.sh} \
              ${appDaemon}/bin/app-daemon \
              ${./contracts/app-api-ui-contract.fixture.json} \
              ${./launcher/AppApi.js}
            touch $out
          '';

          clipDaemonContract = pkgs.runCommand "shelllist-clip-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-clip-api-contract.sh} \
              ${clipDaemon}/bin/clip-daemon \
              ${./contracts/clip-api-ui-contract.fixture.json} \
              ${./clipboard/ClipApi.js}
            touch $out
          '';

          btDaemonContract = pkgs.runCommand "shelllist-bt-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-bt-api-contract.sh} \
              ${btDaemon}/bin/bt-daemon \
              ${./contracts/bt-api-ui-contract.fixture.json} \
              ${./bluetooth/BtApi.js}
            touch $out
          '';

          nmDaemonContract = pkgs.runCommand "shelllist-nm-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-nm-api-contract.sh} \
              ${nmDaemon}/bin/nm-daemon \
              ${./contracts/nm-api-ui-contract.fixture.json} \
              ${./wifi/NmApi.js}
            touch $out
          '';

          barDaemonContract = pkgs.runCommand "shelllist-bar-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-bar-api-contract.sh} \
              ${barDaemon}/bin/bar-daemon \
              ${./contracts/bar-api-ui-contract.fixture.json} \
              ${./bar/BarApi.js} \
              ${./activity/ActivityApi.js}
            touch $out
          '';

          qmlLint = pkgs.runCommand "shelllist-qml-lint"
            {
              nativeBuildInputs = [ pkgs.qt6.qtdeclarative pkgs.quickshell ];
            } ''
            run_qmllint() {
              qmllint \
                -I "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
                -I "${pkgs.quickshell}/lib/qt-6/qml" \
                -I ${./qml} \
                "$@"
            }

            sources=(
              ${./qml}/Shelllist/Core/*.qml
              ${./qml}/Shelllist/Io/*.qml
              ${./qml}/Shelllist/Io/process/*.qml
              ${./qml}/Shelllist/Ui/*.qml
              ${./shell}/*.qml
              ${./bar}/*.qml
              ${./bluetooth}/*.qml
              ${./clipboard}/*.qml
              ${./launcher}/*.qml
              ${./activity}/*.qml
              ${./wifi}/*.qml
              ${./wifi}/networkinput/*.qml
              ${./wifi}/process/*.qml
              ${./tests/qml}/*.qml
            )
            strict_sources=()
            for source in "''${sources[@]}"; do
              case "$source" in
                */ShelllistGlobalShortcut.qml) ;;
                *) strict_sources+=("$source") ;;
              esac
            done

            run_qmllint "''${strict_sources[@]}"
            # Quickshell 0.3's private GlobalShortcut qmltypes reference an
            # unexported PostReloadHook. Suppress only that upstream import warning.
            run_qmllint --import disable ${./qml}/Shelllist/Ui/ShelllistGlobalShortcut.qml
            touch $out
          '';

          barPresentation = pkgs.runCommand "shelllist-bar-presentation"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bar-presentation.js} ${./bar/BarPresentation.js}
            touch $out
          '';

          barSurfaceRecovery = pkgs.runCommand "shelllist-bar-surface-recovery"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bar-surface-recovery.js} ${./shell/BarSurfaceRecovery.js}
            touch $out
          '';

          moduleEvaluation =
            let
              evaluated = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.default
                  { programs.shelllist.enable = true; }
                ];
              };
            in
            pkgs.runCommand "shelllist-module-evaluation" { } ''
              test '${evaluated.config.systemd.user.services.shelllist.serviceConfig.ExecStart}' = '${self.packages.${system}.default}/bin/shelllist run'
              test '${evaluated.config.systemd.user.services.bar-daemon.serviceConfig.BusName}' = 'org.laufan.BarDaemon'
              touch $out
            '';

          applicationPresentation = pkgs.runCommand "shelllist-application-presentation"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-application-presentation.js} ${./launcher/ApplicationPresentation.js}
            touch $out
          '';

          applicationLifecycle = pkgs.runCommand "shelllist-application-lifecycle"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-application-lifecycle.js} ${./launcher/ApplicationLifecycle.js}
            touch $out
          '';

          ipValidation = pkgs.runCommand "shelllist-ip-validation"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-ip-validation.js} ${./wifi/networkinput/IpValidation.js}
            touch $out
          '';

          navigationKeys = pkgs.runCommand "shelllist-navigation-keys"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-navigation-keys.js} ${./qml/Shelllist/Ui/NavigationKeys.js}
            touch $out
          '';

          wifiIcons = pkgs.runCommand "shelllist-wifi-icons"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-wifi-icons.js} ${./wifi/WifiIcons.js}
            touch $out
          '';

          wifiQr = pkgs.runCommand "shelllist-wifi-qr"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-wifi-qr.js} ${./wifi/WifiQr.js}
            touch $out
          '';

          bluetoothLifecycle = pkgs.runCommand "shelllist-bluetooth-lifecycle"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bluetooth-lifecycle.js} ${./bluetooth/BluetoothFlow.js} ${./bluetooth/BtApi.js}
            touch $out
          '';

          qmlTests = pkgs.runCommand "shelllist-qml-tests"
            {
              nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
            } ''
            mkdir -p test-root/tests
            cp -r ${./tests/qml} test-root/tests/qml
            ln -s ${./qml} test-root/qml
            ln -s ${./wifi} test-root/wifi
            export HOME=$TMPDIR
            export XDG_CACHE_HOME=$TMPDIR/cache
            QT_QPA_PLATFORM=offscreen qmltestrunner \
              -input test-root/tests/qml \
              -import ${./qml} \
              -import ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
              -o -,txt
            touch $out
          '';

          bluetoothBattery = pkgs.runCommand "shelllist-bluetooth-battery"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bluetooth-battery.js} ${./bluetooth/BluetoothBattery.js} ${./bluetooth}
            touch $out
          '';

          bluetoothNoiseControl = pkgs.runCommand "shelllist-bluetooth-noise-control"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bluetooth-noise-control.js} ${./bluetooth/BluetoothNoiseControl.js} ${./bluetooth}
            touch $out
          '';

          bluetoothGlyphs = pkgs.runCommand "shelllist-bluetooth-glyphs"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-bluetooth-glyphs.js} ${./bluetooth/BluetoothGlyphs.js}
            touch $out
          '';

          clipboardActions = pkgs.runCommand "shelllist-clipboard-actions"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-clipboard-actions.js} ${./clipboard/ClipApi.js}
            touch $out
          '';

          providerModel = pkgs.runCommand "shelllist-provider-model"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-provider-model.js} ${./qml/Shelllist/Core/Model.js}
            touch $out
          '';
        });

      apps = forAllSystems (system: pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/shelllist";
          meta.description = "Run the single-host Shelllist desktop action center";
        };
        connectParityProbe = {
          type = "app";
          program = "${self.packages.${system}.connectParityProbe}/bin/nm-daemon-connect-parity-probe";
          meta.description = "Destructively compare nm-daemon and nmcli connection attempts for visible Wi-Fi networks";
        };
      });

      devShells = forAllSystems (system: pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.nixpkgs-fmt
            pkgs.qt6.qtdeclarative # qmlformat, qmllint
            pkgs.quickshell
            pkgs.shellcheck
            (pkgs.writeShellApplication {
              name = "shelllist-qmllint";
              runtimeInputs = [ pkgs.qt6.qtdeclarative pkgs.quickshell ];
              text = ''
                run_qmllint() {
                  qmllint \
                    -I "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
                    -I "${pkgs.quickshell}/lib/qt-6/qml" \
                    -I "$PWD/qml" \
                    "$@"
                }

                strict_args=()
                shortcut_files=()
                for arg in "$@"; do
                  case "$arg" in
                    */ShelllistGlobalShortcut.qml)
                      shortcut_files+=("$arg")
                      ;;
                    *) strict_args+=("$arg") ;;
                  esac
                done
                if [ "''${#strict_args[@]}" -gt 0 ]; then
                  run_qmllint "''${strict_args[@]}"
                fi
                if [ "''${#shortcut_files[@]}" -gt 0 ]; then
                  run_qmllint --import disable "''${shortcut_files[@]}"
                fi
              '';
            })
          ];
        };
      });

      formatter = forAllSystems (system: pkgs: pkgs.nixpkgs-fmt);
    };
}
