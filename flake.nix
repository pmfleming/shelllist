{
  description = "Quickshell desktop menu experiments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nm-wifi-rofi = {
      url = "path:/home/laufan/Projects/nm-wifi-rofi-rust";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nm-wifi-rofi }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (system: pkgs:
        let
          nmWifiRofi = nm-wifi-rofi.packages.${system}.default;
        in
        {
          default = pkgs.writeShellApplication {
            name = "shelllist-wifi";
            runtimeInputs = [
              pkgs.gawk
              pkgs.gnugrep
              pkgs.networkmanager
              pkgs.quickshell
              self.packages.${system}.captivePortalBrowser
              nmWifiRofi
            ];
            text = ''
              config_path=${self.packages.${system}.wifiConfig}/share/shelllist/wifi

              # Quickshell identifies path configs by the immutable Nix store path,
              # so each rebuild can leave an older Shelllist instance alive. Make
              # SUPER+M a predictable "show fresh Wi-Fi popup" action while the UI
              # is still a prototype.
              quickshell list --all 2>/dev/null \
                | awk '
                    /^Instance / { pid = ""; shelllist = 0 }
                    /Process ID:/ { pid = $3 }
                    /Config path: .*shelllist-wifi-config.*\/share\/shelllist\/wifi\/shell.qml/ { shelllist = 1 }
                    shelllist && pid != "" { print pid; pid = ""; shelllist = 0 }
                  ' \
                | while read -r pid; do
                    [ -n "$pid" ] && quickshell kill --pid "$pid" >/dev/null 2>&1 || true
                  done

              exec quickshell --path "$config_path" "$@"
            '';
          };

          captivePortalBrowser = pkgs.writeShellApplication {
            name = "shelllist-captive-portal";
            runtimeInputs = [ pkgs.coreutils ];
            text = ''
              profile_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/shelllist-captive-portal-browser"
              mkdir -p "$profile_dir"

              urls=(
                "http://neverssl.com/"
                "http://example.com/"
                "http://captive.apple.com/hotspot-detect.html"
                "http://detectportal.firefox.com/canonical.html"
                "http://www.msftconnecttest.com/connecttest.txt"
                "http://nmcheck.gnome.org/check_network_status.txt"
              )

              if command -v google-chrome-stable >/dev/null 2>&1; then
                browser=google-chrome-stable
              elif command -v google-chrome >/dev/null 2>&1; then
                browser=google-chrome
              elif command -v chromium >/dev/null 2>&1; then
                browser=chromium
              elif command -v xdg-open >/dev/null 2>&1; then
                exec xdg-open "''${urls[0]}"
              else
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
                "''${urls[@]}"
            '';
          };

          wifiConfig = pkgs.stdenvNoCC.mkDerivation {
            pname = "shelllist-wifi-config";
            version = "0.1.0";
            src = ./wifi;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/shelllist/wifi
              cp -r . $out/share/shelllist/wifi/
              runHook postInstall
            '';
          };
        });

      apps = forAllSystems (system: pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/shelllist-wifi";
        };
      });
    };
}
