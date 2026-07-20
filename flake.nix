{
  description = "Quickshell desktop menu experiments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nm-daemon = {
      # Development remains local until the current nm-daemon API history is published.
      url = "git+file:///home/laufan/Projects/nm-daemon?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bt-daemon = {
      # Development remains local until the initial bt-daemon history is published.
      url = "git+file:///home/laufan/Projects/bt-daemon?ref=main";
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
              config_path=${self.packages.${system}.wifiConfig}/share/shelllist/wifi
              export QML_IMPORT_PATH=${self.packages.${system}.wifiConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.wifiConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

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
              config_path=${self.packages.${system}.wifiConfig}/share/shelllist/bluetooth
              export QML_IMPORT_PATH=${self.packages.${system}.wifiConfig}/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${self.packages.${system}.wifiConfig}/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

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
                quickshell --path "$config_path" --daemonize --no-duplicate >/dev/null 2>&1 || true
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
                foreground) exec quickshell --path "$config_path" --no-duplicate ;;
                toggle|open|hide) ensure_daemon && popover_ipc "$action" >/dev/null ;;
                status) ensure_daemon && popover_ipc status ;;
                *) echo "Usage: shelllist-bluetooth [daemon|foreground|toggle|open|hide|status]" >&2; exit 2 ;;
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

          wifiConfig = pkgs.stdenvNoCC.mkDerivation {
            pname = "shelllist-config";
            version = "0.2.0";
            src = ./.;
            meta = {
              description = "QML configuration for the Shelllist Wi-Fi popup";
              platforms = pkgs.lib.platforms.linux;
            };
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/shelllist
              cp -r wifi bluetooth qml $out/share/shelllist/
              runHook postInstall
            '';
          };
        });

      checks = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
        in
        {
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
              ${./qml}/Shelllist/Ui/*.qml
              ${./bluetooth}/*.qml
              ${./wifi}/*.qml
              ${./wifi}/networkinput/*.qml
              ${./wifi}/process/*.qml
            )
            strict_sources=()
            for source in "''${sources[@]}"; do
              case "$source" in
                */BluetoothGlobalShortcut.qml|*/WifiGlobalShortcut.qml) ;;
                *) strict_sources+=("$source") ;;
              esac
            done

            run_qmllint "''${strict_sources[@]}"
            # Quickshell 0.3's private GlobalShortcut qmltypes reference an
            # unexported PostReloadHook. Suppress only that upstream import warning.
            run_qmllint --import disable \
              ${./bluetooth}/BluetoothGlobalShortcut.qml \
              ${./wifi}/WifiGlobalShortcut.qml
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
            node ${./tests/check-bluetooth-lifecycle.js} ${./bluetooth/BluetoothFlow.js}
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
                    */BluetoothGlobalShortcut.qml|*/WifiGlobalShortcut.qml)
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
