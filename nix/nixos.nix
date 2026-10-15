self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.shelllist;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ ./removed-options.nix ];
  options.programs.shelllist = {
    enable = lib.mkEnableOption "Shelllist desktop action center and top bar";
    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.default;
      description = "UI package to install and run; daemons are configured independently.";
    };
    systemd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start Shelllist with the graphical user session.";
      };
      target = lib.mkOption {
        type = lib.types.str;
        default = "graphical-session.target";
        description = "Systemd user target to bind the UI to.";
      };
      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables passed to the Shelllist service.";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.user.services.shelllist = lib.mkIf cfg.systemd.enable {
      description = "Shelllist desktop action center and top bar";
      wantedBy = [ cfg.systemd.target ];
      partOf = [ cfg.systemd.target ];
      after = [ cfg.systemd.target ];
      environment = cfg.systemd.environment;
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/shelllist run";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
