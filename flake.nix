{
  description = "Quickshell desktop menu experiments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nm-daemon = {
      url = "path:/home/laufan/Projects/nm-api";
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
          nmDaemonConnectParityProbe = inputs."nm-daemon".packages.${system}.connectParityProbe;
          nmDaemonPython = pkgs.python3.withPackages (ps: [ ps.dbus-python ps.pygobject3 ]);
          nmDaemonCallPy = pkgs.writeText "shelllist-nm-daemon-call.py" ''
            import sys
            import dbus

            BUS_NAME = "org.laufan.NmDaemon"
            OBJECT_PATH = "/org/laufan/NmDaemon"
            INTERFACE = "org.laufan.NmDaemon1"

            method = sys.argv[1]
            if len(sys.argv) > 2 and sys.argv[2] == "--stdin":
                params = sys.stdin.read().strip() or "{}"
            else:
                params = sys.argv[2] if len(sys.argv) > 2 else "{}"

            bus = dbus.SessionBus()
            proxy = bus.get_object(BUS_NAME, OBJECT_PATH)
            iface = dbus.Interface(proxy, dbus_interface=INTERFACE)
            print(str(iface.Call(method, params)))
          '';
          nmDaemonEventsPy = pkgs.writeText "shelllist-nm-daemon-events.py" ''
            import sys
            import dbus
            import dbus.mainloop.glib
            from gi.repository import GLib

            BUS_NAME = "org.laufan.NmDaemon"
            OBJECT_PATH = "/org/laufan/NmDaemon"
            INTERFACE = "org.laufan.NmDaemon1"

            streams = sys.argv[1:] or ["wifi.scan", "wifi.connect", "wifi.secret"]
            stream_set = set(streams)

            dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
            bus = dbus.SessionBus()
            loop = GLib.MainLoop()

            def handle_event(stream, event_json):
                stream = str(stream)
                if stream in stream_set:
                    print(str(event_json), flush=True)

            bus.add_signal_receiver(
                handle_event,
                signal_name="Event",
                dbus_interface=INTERFACE,
                bus_name=BUS_NAME,
                path=OBJECT_PATH,
            )
            proxy = bus.get_object(BUS_NAME, OBJECT_PATH)
            iface = dbus.Interface(proxy, dbus_interface=INTERFACE)
            iface.Subscribe(dbus.Array(streams, signature="s"))
            loop.run()
          '';
          mkMeta = description: mainProgram: {
            inherit description mainProgram;
            platforms = pkgs.lib.platforms.linux;
          };
        in
        {
          connectParityProbe = nmDaemonConnectParityProbe;

          nmDaemonCall = pkgs.writeShellApplication {
            name = "shelllist-nm-daemon-call";
            meta = mkMeta "Call the Shelllist nm-daemon D-Bus API" "shelllist-nm-daemon-call";
            runtimeInputs = [ nmDaemonPython ];
            text = ''
              if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
                echo "usage: $0 <method> [<params-json>|--stdin]" >&2
                exit 2
              fi
              exec python3 ${nmDaemonCallPy} "$@"
            '';
          };

          nmDaemonEvents = pkgs.writeShellApplication {
            name = "shelllist-nm-daemon-events";
            meta = mkMeta "Stream Shelllist nm-daemon D-Bus events as JSON Lines" "shelllist-nm-daemon-events";
            runtimeInputs = [ nmDaemonPython ];
            text = ''
              exec python3 ${nmDaemonEventsPy} "$@"
            '';
          };

          default = pkgs.writeShellApplication {
            name = "shelllist-wifi";
            meta = mkMeta "Quickshell Wi-Fi popup backed by nm-daemon" "shelllist-wifi";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.networkmanager
              pkgs.quickshell
              self.packages.${system}.captivePortalBrowser
              self.packages.${system}.nmDaemonCall
              self.packages.${system}.nmDaemonEvents
              nmDaemon
            ];
            text = ''
              config_path=${self.packages.${system}.wifiConfig}/share/shelllist/wifi

              kill_shelllist_instances() {
                # Quickshell identifies path configs by the immutable Nix store path,
                # so each rebuild can leave an older Shelllist instance alive. In
                # floating mode this preserves the original one-shot "show fresh popup"
                # behavior; in popover mode we call it only before starting a new daemon.
                quickshell list --all 2>/dev/null \
                  | awk '
                      /^Instance / { pid = ""; shelllist = 0 }
                      /Process ID:/ { pid = $3 }
                      /Config path: .*shelllist-wifi-config.*\/share\/shelllist\/wifi\/shell.qml/ { shelllist = 1 }
                      shelllist && pid != "" { print pid; pid = ""; shelllist = 0 }
                    ' \
                  | while read -r pid; do
                      [ -n "$pid" ] && quickshell kill --pid "$pid" >/dev/null 2>&1 || true
                    done \
                  || true
              }

              run_floating() {
                kill_shelllist_instances
                SHELLLIST_WIFI_MODE=floating exec quickshell --path "$config_path" "$@"
              }

              popover_ipc() {
                quickshell ipc --path "$config_path" --newest call wifi "$@"
              }

              shelllist_no_animations_enabled() {
                case "$(printf '%s' "''${SHELLLIST_NO_ANIMATIONS:-}" | tr '[:upper:]' '[:lower:]')" in
                  1|true|yes|on|disabled|disable|no-animation|no-animations)
                    return 0
                    ;;
                  0|false|no|off|enabled|enable)
                    return 1
                    ;;
                esac

                [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 1
                command -v hyprctl >/dev/null 2>&1 || return 1
                hyprctl getoption animations:enabled 2>/dev/null \
                  | awk '
                      /^(int|bool):/ {
                        value = tolower($2)
                        disabled = (value == "0" || value == "false" || value == "off" || value == "no")
                        found = 1
                      }
                      END { exit found && disabled ? 0 : 1 }
                    '
              }

              sync_popover_animation_rule() {
                [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
                command -v hyprctl >/dev/null 2>&1 || return 0
                if shelllist_no_animations_enabled; then
                  hyprctl keyword layerrule "animation 0 shelllist-wifi" >/dev/null 2>&1 || true
                else
                  hyprctl keyword layerrule "animation unset shelllist-wifi" >/dev/null 2>&1 || true
                fi
              }

              ensure_popover_daemon() {
                if popover_ipc ping >/dev/null 2>&1; then
                  return 0
                fi

                kill_shelllist_instances

                # Long-term this daemon should be the Quickshell bar process itself.
                # While Waybar owns the visible network icon, we keep a small Shelllist
                # daemon alive so Waybar/SUPER+N can toggle the Wi-Fi window over Quickshell IPC.
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
                sync_popover_animation_rule
                popover_ipc "$action" >/dev/null
              }

              case "''${1:-}" in
                floating)
                  shift
                  run_floating "$@"
                  ;;
                daemon)
                  ensure_popover_daemon
                  ;;
                toggle|show|hide)
                  action=$1
                  shift
                  popover_call "$action"
                  ;;
                *)
                  if [ "''${SHELLLIST_WIFI_MODE:-floating}" = popover ] && [ "$#" -eq 0 ]; then
                    popover_call toggle
                  else
                    run_floating "$@"
                  fi
                  ;;
              esac
            '';
          };

          captivePortalBrowser = pkgs.writeShellApplication {
            name = "shelllist-captive-portal";
            meta = mkMeta "Open browser pages that trigger captive portal login flows" "shelllist-captive-portal";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              state_dir="''${XDG_RUNTIME_DIR:-/tmp}/shelllist-captive-portal"
              profile_dir="$state_dir/browser-profile"
              stamp_file="$state_dir/last-opened"
              mkdir -p "$profile_dir"

              now=$(date +%s)
              if [ -f "$stamp_file" ]; then
                last=$(cat "$stamp_file")
                if [ $((now - last)) -lt 12 ]; then
                  exit 0
                fi
              fi
              printf '%s\n' "$now" > "$stamp_file"

              portal_url="http://neverssl.com/"

              browser=
              for candidate in google-chrome-stable google-chrome chromium; do
                if command -v "$candidate" >/dev/null 2>&1; then
                  browser=$candidate
                  break
                fi
              done

              if [ -z "$browser" ]; then
                if command -v xdg-open >/dev/null 2>&1; then
                  exec xdg-open "$portal_url"
                fi
                echo "No supported browser found for captive portal" >&2
                exit 1
              fi

              exec "$browser" \
                --user-data-dir="$profile_dir" \
                --no-first-run \
                --no-default-browser-check \
                --disable-search-engine-choice-screen \
                --new-window \
                --disable-extensions \
                --disable-quic \
                --disable-features=HttpsUpgrades,HttpsFirstBalancedModeAutoEnable,HttpsFirstModeV2,DnsOverHttpsUpgrade \
                --no-proxy-server \
                --app="$portal_url"
            '';
          };

          wifiConfig = pkgs.stdenvNoCC.mkDerivation {
            pname = "shelllist-wifi-config";
            version = "0.1.0";
            src = ./wifi;
            meta = {
              description = "QML configuration for the Shelllist Wi-Fi popup";
              platforms = pkgs.lib.platforms.linux;
            };
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/shelllist/wifi
              cp -r . $out/share/shelllist/wifi/
              runHook postInstall
            '';
          };
        });

      checks = forAllSystems (system: pkgs:
        let
          nmDaemon = inputs."nm-daemon".packages.${system}.default;
        in
        {
          nmDaemonContract = pkgs.runCommand "shelllist-nm-daemon-contract"
            {
              nativeBuildInputs = [ pkgs.diffutils pkgs.jq ];
            } ''
            ${pkgs.bash}/bin/bash ${./tests/check-nm-api-contract.sh} \
              ${nmDaemon}/bin/nm-daemon \
              ${./contracts/nm-api-ui-contract.fixture.json}
            touch $out
          '';
        });

      apps = forAllSystems (system: pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/shelllist-wifi";
          meta.description = "Run the Shelllist Wi-Fi Quickshell popup";
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
                exec qmllint \
                  -I "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml" \
                  -I "${pkgs.quickshell}/lib/qt-6/qml" \
                  -I "$PWD/wifi" \
                  "$@"
              '';
            })
          ];
        };
      });

      formatter = forAllSystems (system: pkgs: pkgs.nixpkgs-fmt);
    };
}
