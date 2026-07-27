{
  description = "Quickshell desktop menu experiments";

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
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
          clipDaemon = inputs."clip-daemon".packages.${system}.default;
          nmDaemonConnectParityProbe = inputs."nm-daemon".packages.${system}.connectParityProbe;
          mkMeta = description: mainProgram: {
            inherit description mainProgram;
            platforms = pkgs.lib.platforms.linux;
          };
        in
        {
          connectParityProbe = nmDaemonConnectParityProbe;

          default = pkgs.writeShellApplication {
            name = "shelllist-wifi";
            meta = mkMeta "Quickshell Wi-Fi popup backed by nm-daemon" "shelllist-wifi";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.quickshell
              self.packages.${system}.captivePortalBrowser
              nmDaemon
            ];
            text = ''
              config_path=${self.packages.${system}.shelllistConfig}/share/shelllist/wifi
              export QML_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

              stop_stale_shelllist_instances() {
                # Rebuilt path configs have a new store path. Retire an older resident
                # instance only when the current config cannot answer IPC.
                quickshell list --all 2>/dev/null \
                  | awk '
                      /^Instance / { pid = ""; shelllist = 0 }
                      /Process ID:/ { pid = $3 }
                      /Config path: .*shelllist-(wifi-)?config.*\/share\/shelllist\/wifi\/shell.qml/ { shelllist = 1 }
                      shelllist && pid != "" { print pid; pid = ""; shelllist = 0 }
                    ' \
                  | while read -r pid; do
                      [ -n "$pid" ] && quickshell kill --pid "$pid" >/dev/null 2>&1 || true
                    done \
                  || true
              }

              run_floating() {
                SHELLLIST_WIFI_MODE=floating exec quickshell --path "$config_path" "$@"
              }

              popover_ipc() {
                quickshell ipc --path "$config_path" --newest call wifi "$@"
              }

              ensure_popover_daemon() {
                if popover_ipc ping >/dev/null 2>&1; then
                  return 0
                fi

                stop_stale_shelllist_instances
                SHELLLIST_WIFI_MODE=popover quickshell --path "$config_path" --daemonize --no-duplicate >/dev/null 2>&1 || true

                attempts=0
                while [ "$attempts" -lt 20 ]; do
                  if popover_ipc ping >/dev/null 2>&1; then
                    return 0
                  fi
                  attempts=$((attempts + 1))
                  sleep 0.05
                done

                echo "Shelllist Wi-Fi popover daemon did not become ready" >&2
                return 1
              }

              popover_call() {
                action=$1
                if [ "$action" = show ]; then
                  action=open
                fi
                ensure_popover_daemon || return 1
                popover_ipc "$action" >/dev/null
              }

              popover_status() {
                ensure_popover_daemon || return 1
                popover_ipc status
              }

              case "''${1:-}" in
                floating)
                  shift
                  run_floating "$@"
                  ;;
                daemon)
                  ensure_popover_daemon
                  ;;
                toggle|open|show|hide)
                  action=$1
                  shift
                  popover_call "$action"
                  ;;
                status)
                  shift
                  popover_status
                  ;;
                *)
                  if [ "''${SHELLLIST_WIFI_MODE:-popover}" = floating ]; then
                    run_floating "$@"
                  else
                    popover_call toggle
                  fi
                  ;;
              esac
            '';
          };

          bluetooth = pkgs.writeShellApplication {
            name = "shelllist-bluetooth";
            meta = mkMeta "Quickshell Bluetooth popup backed by bt-daemon" "shelllist-bluetooth";
            runtimeInputs = [ pkgs.coreutils pkgs.gawk pkgs.quickshell btDaemon ];
            text = ''
              config_path=${self.packages.${system}.shelllistConfig}/share/shelllist/bluetooth
              export QML_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

              run_floating() {
                SHELLLIST_BLUETOOTH_MODE=floating exec quickshell --path "$config_path" "$@"
              }

              popover_ipc() {
                quickshell ipc --path "$config_path" --newest call bluetooth "$@"
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

              ensure_daemon() {
                if current_daemon_running && popover_ipc ping >/dev/null 2>&1; then return 0; fi
                quickshell list --all 2>/dev/null \
                  | awk '/Process ID:/ { pid = $3 } /Config path: .*share\/shelllist\/bluetooth\/shell.qml/ { if (pid != "") print pid }' \
                  | while read -r pid; do quickshell kill --pid "$pid" >/dev/null 2>&1 || true; done || true
                SHELLLIST_BLUETOOTH_MODE=popover quickshell --path "$config_path" --daemonize --no-duplicate >/dev/null 2>&1 || true
                attempts=0
                while [ "$attempts" -lt 30 ]; do
                  if popover_ipc ping >/dev/null 2>&1; then return 0; fi
                  attempts=$((attempts + 1)); sleep 0.05
                done
                echo "Shelllist Bluetooth popover did not become ready" >&2
                return 1
              }

              action=''${1:-toggle}
              [ "$action" = show ] && action=open
              case "$action" in
                daemon) ensure_daemon ;;
                floating) shift; run_floating "$@" ;;
                foreground) SHELLLIST_BLUETOOTH_MODE=popover exec quickshell --path "$config_path" --no-duplicate ;;
                toggle|open|hide) ensure_daemon && popover_ipc "$action" >/dev/null ;;
                status) ensure_daemon && popover_ipc status ;;
                *) echo "Usage: shelllist-bluetooth [daemon|floating|foreground|toggle|open|hide|status]" >&2; exit 2 ;;
              esac
            '';
          };

          clipboard = pkgs.writeShellApplication {
            name = "shelllist-clipboard";
            meta = mkMeta "Quickshell clipboard history backed by clip-daemon" "shelllist-clipboard";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.jq
              pkgs.quickshell
              clipDaemon
            ];
            text = ''
              config_path=${self.packages.${system}.shelllistConfig}/share/shelllist/clipboard
              export QML_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

              popover_ipc() {
                quickshell ipc --path "$config_path" --newest call clipboard "$@"
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
              ensure_daemon() {
                if current_daemon_running && popover_ipc ping >/dev/null 2>&1; then return 0; fi
                SHELLLIST_CLIPBOARD_MODE=popover quickshell --path "$config_path" --daemonize --no-duplicate >/dev/null 2>&1 || true
                attempts=0
                while [ "$attempts" -lt 30 ]; do
                  if popover_ipc ping >/dev/null 2>&1; then return 0; fi
                  attempts=$((attempts + 1)); sleep 0.05
                done
                echo "Shelllist Clipboard popover did not become ready" >&2
                return 1
              }

              usage() {
                cat <<'EOF'
Usage: shelllist-clipboard [OPTIONS] [ACTION]

Clipboard settings:
  --pause         Pause history capture
  --private       Pause capture in private mode
  --resume        Resume history capture
  --kept COUNT    Set the maximum number of regular history entries

Actions: daemon, floating, foreground, toggle, open, show, hide, status
Setting options used without an action update clip-daemon and exit.
EOF
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

              capture_mode=
              kept=
              configured=0
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  --pause|--private|--resume)
                    requested_mode=''${1#--}
                    if [ -n "$capture_mode" ] && [ "$capture_mode" != "$requested_mode" ]; then
                      echo "Only one of --pause, --private, or --resume may be used" >&2
                      exit 2
                    fi
                    capture_mode=$requested_mode
                    configured=1
                    shift
                    ;;
                  --kept)
                    if [ "$#" -lt 2 ]; then
                      echo "--kept requires an entry count" >&2
                      exit 2
                    fi
                    case "$2" in
                      ""|*[!0-9]*) echo "--kept must be a positive integer" >&2; exit 2 ;;
                    esac
                    kept=$2
                    configured=1
                    shift 2
                    ;;
                  -h|--help)
                    usage
                    exit 0
                    ;;
                  --)
                    shift
                    break
                    ;;
                  -*)
                    echo "Unknown option: $1" >&2
                    usage >&2
                    exit 2
                    ;;
                  *) break ;;
                esac
              done

              if [ -n "$capture_mode" ]; then
                paused=true
                private=false
                if [ "$capture_mode" = private ]; then
                  private=true
                elif [ "$capture_mode" = resume ]; then
                  paused=false
                fi
                request=$(jq -cn --argjson paused "$paused" --argjson private "$private" \
                  '{op:"call", id:"shelllist-cli", method:"clipboard.capture.setPaused", params:{paused:$paused, private_mode:$private}}')
                clip_call "$request"
                case "$capture_mode" in
                  pause) echo "Clipboard history capture paused" ;;
                  private) echo "Private mode enabled; clipboard history capture paused" ;;
                  resume) echo "Clipboard history capture resumed" ;;
                esac
              fi

              if [ -n "$kept" ]; then
                request=$(jq -cn --argjson kept "$kept" \
                  '{op:"call", id:"shelllist-cli", method:"clipboard.settings.update", params:{max_entries:$kept}}')
                clip_call "$request"
                echo "Clipboard retention set to $kept entries"
              fi

              action=''${1:-}
              if [ "$#" -gt 0 ]; then shift; fi
              if [ "$#" -gt 0 ]; then
                usage >&2
                exit 2
              fi
              if [ -z "$action" ]; then
                if [ "$configured" -eq 1 ]; then exit 0; fi
                action=toggle
              fi
              [ "$action" = show ] && action=open
              case "$action" in
                daemon) ensure_daemon ;;
                floating) SHELLLIST_CLIPBOARD_MODE=floating exec quickshell --path "$config_path" ;;
                foreground) SHELLLIST_CLIPBOARD_MODE=popover exec quickshell --path "$config_path" --no-duplicate ;;
                toggle|open|hide) ensure_daemon && popover_ipc "$action" >/dev/null ;;
                status) ensure_daemon && popover_ipc status ;;
                *) usage >&2; exit 2 ;;
              esac
            '';
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
                if [ -n "$workspace" ]; then
                  hyprctl dispatch movetoworkspacesilent "$workspace,class:^($window_class)$" >/dev/null 2>&1 || true
                fi
                hyprctl dispatch focuswindow "class:^($window_class)$" >/dev/null 2>&1 || true
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
              cp -r wifi bluetooth clipboard qml $out/share/shelllist/
              runHook postInstall
            '';
          };
        });

      checks = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
          clipDaemon = inputs."clip-daemon".packages.${system}.default;
        in
        {
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
              ${./bluetooth}/*.qml
              ${./clipboard}/*.qml
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

          ipValidation = pkgs.runCommand "shelllist-ip-validation"
            {
              nativeBuildInputs = [ pkgs.nodejs ];
            } ''
            node ${./tests/check-ip-validation.js} ${./wifi/networkinput/IpValidation.js}
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
            node ${./tests/check-bluetooth-battery.js} ${./bluetooth/BluetoothBattery.js}
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
          program = "${self.packages.${system}.default}/bin/shelllist-wifi";
          meta.description = "Run the Shelllist Wi-Fi Quickshell popup";
        };
        bluetooth = {
          type = "app";
          program = "${self.packages.${system}.bluetooth}/bin/shelllist-bluetooth";
          meta.description = "Run the Shelllist Bluetooth Quickshell popup";
        };
        clipboard = {
          type = "app";
          program = "${self.packages.${system}.clipboard}/bin/shelllist-clipboard";
          meta.description = "Run the Shelllist Clipboard Quickshell popup";
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
