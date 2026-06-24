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
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs:
        let
          nmWifiRofi = nm-wifi-rofi.packages.${pkgs.system}.default;
        in
        {
          default = pkgs.writeShellApplication {
            name = "shelllist-wifi";
            runtimeInputs = [
              pkgs.quickshell
              nmWifiRofi
            ];
            text = ''
              exec quickshell --no-duplicate --path ${self.packages.${pkgs.system}.wifiConfig}/share/shelllist/wifi "$@"
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

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.system}.default}/bin/shelllist-wifi";
        };
      });
    };
}
