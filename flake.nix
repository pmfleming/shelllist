{
  description = "Single-host Quickshell desktop action center";

  # CO-DEVELOPMENT INVARIANT: all five consumers follow ONE current framework.
  # tools/local-build in daemon-framework resolves worktrees once per run.
  # Never add local revision pins or private/vendored framework dependencies.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    daemon-framework = {
      url = "git+file:../daemon-framework";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nm-daemon = {
      url = "git+file:../nm-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.daemonFramework.follows = "daemon-framework";
    };
    bt-daemon = {
      url = "git+file:../bt-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.daemonFramework.follows = "daemon-framework";
    };
    clip-daemon = {
      url = "git+file:../clip-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.daemonFramework.follows = "daemon-framework";
    };
    app-daemon = {
      url = "git+file:../app-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.daemonFramework.follows = "daemon-framework";
    };
    bar-daemon = {
      url = "git+file:../bar-daemon";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.daemonFramework.follows = "daemon-framework";
    };
  };

  outputs =
    inputs@{ self, nixpkgs, ... }:
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

      packages = forAllSystems (
        system: pkgs:
        let
          shelllistSearch = pkgs.rustPlatform.buildRustPackage {
            pname = "shelllist-search";
            version = "0.1.0";
            src = ./rust/shelllist-search;
            cargoLock.lockFile = ./rust/shelllist-search/Cargo.lock;
            meta = mkMeta "Fuzzy result ranking service for Shelllist" "shelllist-search";
          };
          shelllistTimezoneAssets = pkgs.rustPlatform.buildRustPackage {
            pname = "shelllist-timezone-assets";
            version = "0.1.0";
            src = ./rust/shelllist-timezone-assets;
            cargoLock.lockFile = ./rust/shelllist-timezone-assets/Cargo.lock;
            meta = mkMeta "Generate Shelllist timezone overlay assets" "shelllist-timezone-assets";
          };
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

          inherit shelllistSearch shelllistTimezoneAssets;

          materialColors = import ./nix/material-colors.nix { inherit pkgs; };

          # Development-only: never part of the resident host or installed bar.
          materialGallery = pkgs.writeShellApplication {
            name = "shelllist-material-gallery";
            runtimeInputs = [ pkgs.quickshell ];
            text = ''
              export FONTCONFIG_FILE=${
                pkgs.makeFontsConf {
                  fontDirectories = [
                    pkgs.roboto-flex
                    pkgs.material-symbols
                    pkgs.noto-fonts
                    pkgs.nerd-fonts.jetbrains-mono
                  ];
                }
              }
              export QML_IMPORT_PATH=${self.packages.${system}.shelllistConfig}/share/shelllist/qml
              export QML2_IMPORT_PATH="$QML_IMPORT_PATH"
              exec quickshell --no-color --path ${./dev/material-gallery.qml} "$@"
            '';
          };

          shelllistApplication = pkgs.writeShellApplication {
            name = "shelllist";
            meta = mkMeta "Single-host Shelllist desktop action center" "shelllist";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.jq
              pkgs.quickshell
              pkgs.hyprland # hyprctl: layer rules and live workspace placement
              self.packages.${system}.shelllistSearch
              pkgs.kdePackages.qrca
              self.packages.${system}.portalLauncher
              nmDaemon
              btDaemon
              clipDaemon
              appDaemon
              barDaemon
              pkgs.pavucontrol
              pkgs.libnotify # background application-action failures
              pkgs.ghostty
            ];
            text = ''
              config_path=${self.packages.${system}.shelllistConfig}/share/shelllist/shell
              export FONTCONFIG_FILE=${
                pkgs.makeFontsConf {
                  fontDirectories = [
                    pkgs.roboto-flex
                    pkgs.material-symbols
                    pkgs.noto-fonts
                    pkgs.nerd-fonts.jetbrains-mono
                  ];
                }
              }
              export QML_IMPORT_PATH=${
                self.packages.${system}.shelllistConfig
              }/share/shelllist/qml''${QML_IMPORT_PATH:+:$QML_IMPORT_PATH}
              export QML2_IMPORT_PATH=${
                self.packages.${system}.shelllistConfig
              }/share/shelllist/qml''${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}

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
                shelllist responsiveness          Print latest interaction timings as JSON
                shelllist list                    List surfaces as JSON
                shelllist daemon                  Ensure the resident host is running
                shelllist run                     Run the resident host in the foreground

              Surfaces: applications, wifi, bluetooth, clipboard, displays, battery, activity, notifications, time-weather, audio, media, tray

              Clipboard settings:
                shelllist clipboard pause
                shelllist clipboard private
                shelllist clipboard resume
                shelllist clipboard kept COUNT
              EOF
              }

              valid_surface() {
                case "$1" in
                  applications|wifi|bluetooth|clipboard|battery|displays|activity|notifications|time-weather|audio|media|tray) return 0 ;;
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
                      /Config path: .*share\/shelllist\/(shell|wifi|bluetooth|clipboard|launcher|battery|activity)\/shell.qml/ { shelllist = 1 }
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
                responsiveness)
                  [ "$#" -eq 1 ] || { usage >&2; exit 2; }
                  ensure_daemon && popover_ipc responsiveness
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
                applications|wifi|bluetooth|displays|battery|activity|notifications|time-weather|audio|media|tray)
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
            paths = [
              self.packages.${system}.shelllistApplication
              barDaemon
            ];
            meta = mkMeta "Single-host Shelllist desktop action center" "shelllist";
          };

          portalLauncher = pkgs.rustPlatform.buildRustPackage {
            pname = "shelllist-portal-launch";
            version = "0.1.0";
            src = pkgs.lib.fileset.toSource {
              root = ./.;
              fileset = ./portal-launcher;
            };
            postUnpack = ''
              cp -R --no-preserve=mode ${inputs.daemon-framework} "$(dirname "$sourceRoot")/daemon-framework"
              sourceRoot="$sourceRoot/portal-launcher"
            '';
            cargoLock.lockFile = ./portal-launcher/Cargo.lock;
            meta = mkMeta "Frontend-owned portal browser and native compositor launcher" "shelllist-portal-launch";
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
              cp -r shell bar wifi bluetooth clipboard launcher battery displays activity qml $out/share/shelllist/
              runHook postInstall
            '';
          };
        }
      );

      checks = forAllSystems (
        system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
          btDaemon = inputs."bt-daemon".packages.${system}.default;
          clipDaemon = inputs."clip-daemon".packages.${system}.default;
          appDaemon = inputs."app-daemon".packages.${system}.default;
          barDaemon = inputs."bar-daemon".packages.${system}.default;
          nodeCheck =
            name: commands:
            pkgs.runCommand "shelllist-${name}" { nativeBuildInputs = [ pkgs.nodejs ]; } ''
              ${pkgs.lib.concatMapStringsSep "\n" (
                command: "node ${pkgs.lib.escapeShellArgs (map (arg: "${arg}") command)}"
              ) commands}
              touch $out
            '';
          apiContract =
            label: daemon: coverage: apiFiles:
            pkgs.runCommand "shelllist-${label}-daemon-contract"
              {
                nativeBuildInputs = [
                  pkgs.diffutils
                  pkgs.jq
                ];
              }
              ''
                ${pkgs.bash}/bin/bash ${./tests/check-api-contract.sh} ${label}-api \
                  ${daemon}/bin/${label}-daemon \
                  ${./contracts + "/${label}-api-ui-contract.fixture.json"} \
                  ${./contracts + "/${label}-api-ui-contract.assertions.jq"} \
                  ${pkgs.lib.escapeShellArgs ([ coverage ] ++ map (file: "${file}") apiFiles)}
                touch $out
              '';
        in
        {
          # Flake checks do not recurse into inputs. Keep the shared framework
          # suite and all consumer package tests in the mandatory local matrix.
          frameworkWorkspace = inputs.daemon-framework.checks.${system}.workspace;
          localBuildPolicy = inputs.daemon-framework.checks.${system}.localBuild;
          appDaemonPackage = appDaemon;
          barDaemonPackage = barDaemon;
          btDaemonPackage = btDaemon;
          clipDaemonPackage = clipDaemon;
          nmDaemonPackage = nmDaemon;
          otherSourceSnapshots =
            pkgs.runCommand "shelllist-other-source-snapshots" { nativeBuildInputs = [ pkgs.diffutils ]; }
              ''
                diff -q ${./rust/shelllist-search}/Cargo.toml ${inputs.clip-daemon}/vendor/shelllist-search/Cargo.toml
                diff -qr ${./rust/shelllist-search}/src ${inputs.clip-daemon}/vendor/shelllist-search/src
                touch $out
              '';
          appResourceContract =
            pkgs.runCommand "shelllist-app-resource-contract"
              {
                nativeBuildInputs = [
                  pkgs.diffutils
                  pkgs.jq
                ];
              }
              ''
                ${appDaemon}/bin/app-daemon debug resource-contract-fixture > actual.json
                diff -u \
                  <(jq -S . ${./contracts/app-resource-ui-contract.fixture.json}) \
                  <(jq -S . actual.json)
                touch $out
              '';

          hypridleReadiness =
            pkgs.runCommand "shelllist-hypridle-readiness"
              {
                nativeBuildInputs = [
                  pkgs.stdenv.cc
                  pkgs.python3
                ];
              }
              ''
                cp ${inputs.bar-daemon}/packaging/hypridle/hypridle-ready.hpp readiness.hpp
                printf '#include "readiness.hpp"\nint main() { return shelllistNotifyReady() ? 0 : 1; }\n' > probe.cpp
                c++ -std=c++20 probe.cpp -o probe
                python3 ${./tests/check-hypridle-readiness.py} \
                  ${inputs.bar-daemon.packages.${system}.managedHypridle}/bin/hypridle ./probe
                touch $out
              '';

          appDaemonContract = apiContract "app" appDaemon "registry" [ ./launcher/AppApi.js ];

          clipDaemonContract = apiContract "clip" clipDaemon "registry" [ ./clipboard/ClipApi.js ];

          btDaemonContract = apiContract "bt" btDaemon "api:bluetooth|pairing" [ ./bluetooth/BtApi.js ];

          nmDaemonContract =
            pkgs.runCommand "shelllist-nm-daemon-contract"
              {
                nativeBuildInputs = [
                  pkgs.diffutils
                  pkgs.jq
                ];
              }
              ''
                ${pkgs.bash}/bin/bash ${./tests/check-nm-api-contract.sh} \
                  ${nmDaemon}/bin/nm-daemon \
                  ${./contracts/nm-api-ui-contract.fixture.json} \
                  ${./wifi/NmApi.js}
                touch $out
              '';

          barDaemonContract =
            apiContract "bar" barDaemon
              "api:bar|activity|todos|workspace|media|audio|brightness|battery|powerProfile|powerSleep|displayPolicy|displayLayout|displayFocus|display-policy|power-profile|power-sleep|sleep-policy|osd-hardware|notifications|updates|timezone"
              [
                ./bar/BarApi.js
                ./activity/ActivityApi.js
                ./battery/BatteryApi.js
                ./displays/DisplayApi.js
              ];

          qmlLint =
            pkgs.runCommand "shelllist-qml-lint"
              {
                nativeBuildInputs = [
                  pkgs.qt6.qtdeclarative
                  pkgs.quickshell
                ];
              }
              ''
                run_qmllint() {
                  qmllint --max-warnings 0 \
                    -I "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
                    -I "${pkgs.quickshell}/lib/qt-6/qml" \
                    -I ${./.}/qml \
                    "$@"
                }

                # Preserve relative test imports and Shelllist module symlinks.
                # Separate Nix paths for each directory silently broke resolution
                # while qmllint still exited successfully with warnings.
                sources=(
                  ${./.}/qml/Shelllist/Core/*.qml
                  ${./.}/qml/Shelllist/Io/*.qml
                  ${./.}/qml/Shelllist/Io/process/*.qml
                  ${./.}/qml/Shelllist/Ui/*.qml
                  ${./.}/shell/*.qml
                  ${./.}/bar/*.qml
                  ${./.}/bluetooth/*.qml
                  ${./.}/clipboard/*.qml
                  ${./.}/launcher/*.qml
                  ${./.}/battery/*.qml
                  ${./.}/displays/*.qml
                  ${./.}/activity/*.qml
                  ${./.}/wifi/*.qml
                  ${./.}/wifi/networkinput/*.qml
                  ${./.}/wifi/process/*.qml
                  ${./.}/tests/qml/*.qml
                  ${./.}/dev/*.qml
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
                run_qmllint --import disable ${./.}/qml/Shelllist/Ui/ShelllistGlobalShortcut.qml
                touch $out
              '';

          materialGallery = pkgs.runCommand "shelllist-material-gallery-smoke" { } ''
            export HOME="$TMPDIR/home"
            export XDG_RUNTIME_DIR="$TMPDIR/runtime"
            mkdir -p "$HOME" "$XDG_RUNTIME_DIR"
            chmod 700 "$XDG_RUNTIME_DIR"
            export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software WAYLAND_DISPLAY=
            export SHELLLIST_GALLERY_SMOKE=1
            for scheme in light dark; do
              status=0
              SHELLLIST_GALLERY_SCHEME="$scheme" timeout 30 ${
                self.packages.${system}.materialGallery
              }/bin/shelllist-material-gallery > log 2>&1 || status=$?
              cat log
              if [ "$status" -ne 0 ]; then exit "$status"; fi
              if grep -Ei 'TypeError|ReferenceError|Binding loop|failed to load|WARN|ERROR' log; then
                exit 1
              fi
            done
            touch $out
          '';

          materialColors =
            pkgs.runCommand "shelllist-material-colors-current"
              {
                nativeBuildInputs = [
                  pkgs.nodejs
                  pkgs.diffutils
                ];
              }
              ''
                generated=${self.packages.${system}.materialColors}
                diff -u "$generated/MaterialColors.generated.js" ${./qml/Shelllist/Ui/MaterialColors.generated.js}
                cmp "$generated/material-color-utilities.LICENSE" ${./qml/Shelllist/Ui/material-color-utilities.LICENSE}
                node ${./tests/check-material-colors.js} "$generated/MaterialColors.generated.js"
                touch $out
              '';

          typescript =
            pkgs.runCommand "shelllist-typescript-current"
              {
                nativeBuildInputs = [
                  pkgs.nodejs
                  pkgs.typescript
                ];
              }
              ''
                node ${./.}/tools/build-typescript.mjs --check
                tsc --project ${./.}/tsconfig.json
                touch $out
              '';

          timezoneAssets =
            pkgs.runCommand "shelllist-timezone-assets-current"
              {
                nativeBuildInputs = [
                  pkgs.diffutils
                  self.packages.${system}.shelllistTimezoneAssets
                ];
              }
              ''
                shelllist-timezone-assets \
                  ${./activity/assets/timezones/world-time-zones.svg} generated
                diff -ru ${./activity/assets/timezones/regions} generated
                touch $out
              '';

          displayModel = nodeCheck "display-model" [
            [
              ./tests/check-display-model.js
              ./displays/DisplayModel.js
            ]
          ];

          batteryHistory = nodeCheck "battery-history" [
            [
              ./tests/check-battery-history.js
              ./battery/BatteryHistory.js
            ]
          ];

          batteryAutoSave = nodeCheck "battery-auto-save" [
            [
              ./tests/check-battery-controls.js
              ./battery/BatteryController.qml
              ./battery/BatteryFlow.js
              ./battery/BatteryPresentation.js
            ]
          ];

          moduleEvaluation =
            let
              evaluated = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.default
                  { programs.shelllist.enable = true; }
                ];
              };
              withoutDiscovery = nixpkgs.lib.nixosSystem {
                inherit system;
                modules = [
                  self.nixosModules.default
                  {
                    programs.shelllist = {
                      enable = true;
                      discovery.enable = false;
                    };
                  }
                ];
              };
            in
            pkgs.runCommand "shelllist-module-evaluation" { } ''
              test '${evaluated.config.systemd.user.services.shelllist.serviceConfig.ExecStart}' = '${
                self.packages.${system}.default
              }/bin/shelllist run'
              test '${evaluated.config.systemd.user.services.bar-daemon.serviceConfig.BusName}' = 'org.laufan.BarDaemon'
              test '${evaluated.config.systemd.user.services.bar-daemon.environment.BAR_DAEMON_NOTIFICATION_BACKEND}' = 'native'
              test '${builtins.concatStringsSep " " evaluated.config.systemd.user.services.bar-daemon.conflicts}' = 'swaync.service'
              test '${toString evaluated.config.security.polkit.enable}' = '1'
              test '${toString evaluated.config.networking.networkmanager.enable}' = '1'
              test '${evaluated.config.networking.networkmanager.dns}' = 'systemd-resolved'
              test '${toString evaluated.config.networking.networkmanager.connectionConfig.mdns}' = '0'
              test '${toString evaluated.config.services.resolved.enable}' = '1'
              test '${evaluated.config.services.resolved.settings.Resolve.MulticastDNS}' = 'resolve'
              test '${toString (builtins.elem 5353 evaluated.config.networking.firewall.allowedUDPPorts)}' = '1'
              test '${toString withoutDiscovery.config.services.resolved.enable}' = ""
              test '${toString withoutDiscovery.config.networking.networkmanager.enable}' = ""
              test '${toString (builtins.elem 5353 withoutDiscovery.config.networking.firewall.allowedUDPPorts)}' = ""
              test '${toString evaluated.config.programs.shelllist.resources.enableRaplAccess}' = '1'
              printf '%s' ${nixpkgs.lib.escapeShellArg evaluated.config.services.udev.extraRules} \
                | grep -F 'SUBSYSTEM=="powercap"' >/dev/null
              test -f '${
                self.packages.${system}.default
              }/share/dbus-1/services/org.freedesktop.Notifications.service'
              test -f '${
                self.packages.${system}.default
              }/share/dbus-1/system-services/org.laufan.BarBatteryHelper.service'
              test -f '${self.packages.${system}.default}/share/dbus-1/system.d/org.laufan.BarBatteryHelper.conf'
              test -f '${self.packages.${system}.default}/share/polkit-1/actions/org.laufan.bar-daemon.policy'
              test -f '${self.packages.${system}.default}/lib/systemd/system/bar-battery-helper.service'
              touch $out
            '';

          packagedImports = nodeCheck "packaged-imports" [
            [
              ./tests/check-packaged-imports.js
              "${self.packages.${system}.shelllistConfig}/share/shelllist"
            ]
          ];

          applicationResources = nodeCheck "application-resources" [
            [
              ./tests/check-application-resources.js
              ./launcher/ApplicationResources.js
              ./contracts/app-resource-ui-contract.fixture.json
            ]
            [
              ./tests/check-resource-availability.js
              ./launcher
            ]
          ];

          performanceBenchmarks =
            pkgs.runCommand "shelllist-performance-benchmarks"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.nodejs
                  pkgs.python3
                ];
              }
              ''
                mkdir -p $out
                PYTHONPYCACHEPREFIX=$TMPDIR/python-cache python -m py_compile \
                  ${./tests/benchmark-resident.py} \
                  ${./tests/benchmark-responsiveness.py}
                node ${./tests/generate-performance-benchmarks.js} \
                  ${./qml/Shelllist/Core/Model.js} $out/qmlbench.json
                test "$(jq -r '."rank-empty-1000-results-per-second"."samples-in-average"' \
                  $out/qmlbench.json)" -ge 10
              '';

          applicationLifecycle = nodeCheck "application-lifecycle" [
            [
              ./tests/check-application-lifecycle.js
              ./launcher/ApplicationLifecycle.js
            ]
            [
              ./tests/check-application-history.js
              ./launcher
            ]
          ];

          flowPolicies = nodeCheck "flow-policies" [
            [
              ./tests/check-flow-policies.js
              ./clipboard/ClipboardFlow.js
            ]
          ];

          ipValidation = nodeCheck "ip-validation" [
            [
              ./tests/check-ip-validation.js
              ./wifi/networkinput/IpValidation.js
            ]
          ];

          daemonBoundary = nodeCheck "daemon-boundary" [
            [
              ./tests/check-daemon-boundary.js
              ./.
            ]
          ];

          notificationPresentation = nodeCheck "notification-presentation" [
            [
              ./tests/check-notification-presentation.js
              ./qml/Shelllist/Ui/NotificationPresentation.js
            ]
          ];

          networkHealth = nodeCheck "network-health" [
            [
              ./tests/check-network-health.js
              ./wifi/NetworkHealth.js
            ]
          ];

          bluetoothLifecycle = nodeCheck "bluetooth-lifecycle" [
            [
              ./tests/check-bluetooth-lifecycle.js
              ./bluetooth/BluetoothFlow.js
            ]
          ];

          qmlTests =
            pkgs.runCommand "shelllist-qml-tests"
              {
                nativeBuildInputs = [
                  pkgs.qt6.qtdeclarative
                  pkgs.qt6.qtsvg
                ];
              }
              ''
                mkdir -p test-root/tests
                cp -r ${./tests/qml} test-root/tests/qml
                cp -r ${./qml} test-root/qml
                chmod -R u+w test-root/qml
                ln -sfn ${./battery} test-root/qml/Shelllist/Battery
                ln -sfn ${./displays} test-root/qml/Shelllist/Displays
                ln -sfn ${./activity} test-root/qml/Shelllist/Activity
                ln -sfn ${./bar} test-root/qml/Shelllist/Bar
                ln -s ${./displays} test-root/displays
                ln -s ${./bar} test-root/bar
                ln -s ${./clipboard} test-root/clipboard
                ln -s ${./wifi} test-root/wifi
                ln -s ${./bluetooth} test-root/bluetooth
                ln -s ${./launcher} test-root/launcher
                ln -s ${./shell} test-root/shell
                export HOME=$TMPDIR
                export XDG_CACHE_HOME=$TMPDIR/cache
                export QT_PLUGIN_PATH=${pkgs.qt6.qtsvg}/lib/qt-6/plugins
                export TZDIR=${pkgs.tzdata}/share/zoneinfo
                export TZ=UTC
                QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software qmltestrunner \
                  -input test-root/tests/qml \
                  -import test-root/tests/qml/imports \
                  -import test-root/qml \
                  -import ${pkgs.qt6.qtdeclarative}/lib/qt-6/qml \
                  -o -,txt
                touch $out
              '';

          clipboardActions = nodeCheck "clipboard-actions" [
            [
              ./tests/check-clipboard-actions.js
              ./clipboard/ClipApi.js
              ./clipboard/ClipProtocol.generated.js
              ./clipboard/ClipboardController.qml
              ./clipboard/ClipboardBackend.qml
            ]
          ];

          fuzzySearch = self.packages.${system}.shelllistSearch;

          providerModel = nodeCheck "provider-model" [
            [
              ./tests/check-provider-model.js
              ./qml/Shelllist/Core/Model.js
            ]
          ];
        }
      );

      apps = forAllSystems (
        system: pkgs: {
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
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            shellHook = ''
              export QT_PLUGIN_PATH="${pkgs.qt6.qtsvg}/lib/qt-6/plugins''${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
              export TZDIR="${pkgs.tzdata}/share/zoneinfo"
            '';
            packages = [
              pkgs.nixpkgs-fmt
              pkgs.nodejs
              pkgs.typescript
              pkgs.esbuild
              pkgs.qt6.qtdeclarative # qmlformat, qmllint
              pkgs.qt6.qtsvg # QtTest loads real weather/timezone SVG assets
              pkgs.tzdata
              pkgs.quickshell
              pkgs.shellcheck
              (pkgs.writeShellApplication {
                name = "shelllist-qmllint";
                runtimeInputs = [
                  pkgs.qt6.qtdeclarative
                  pkgs.quickshell
                ];
                text = ''
                  run_qmllint() {
                    qmllint --max-warnings 0 \
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
        }
      );

      formatter = forAllSystems (system: pkgs: pkgs.nixpkgs-fmt);
    };
}
