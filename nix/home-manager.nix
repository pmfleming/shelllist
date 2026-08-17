self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.shelllist;
  system = pkgs.stdenv.hostPlatform.system;
  environment = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.systemd.environment;
in
{
  options.programs.shelllist = {
    enable = lib.mkEnableOption "Shelllist desktop action center and top bar";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.default;
      defaultText = lib.literalExpression "shelllist.packages.${pkgs.system}.default";
      description = "Shelllist package to install and run.";
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
        description = "Systemd user target to bind Shelllist to.";
      };

      startBarDaemon = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Start the bundled bar-daemon instead of waiting for D-Bus activation.";
      };

      environment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Environment variables passed to the Shelllist service.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    systemd.user.services = lib.mkIf cfg.systemd.enable {
      shelllist = {
        Unit = {
          Description = "Shelllist desktop action center and top bar";
          PartOf = [ cfg.systemd.target ];
          After = [ cfg.systemd.target ] ++ lib.optional cfg.systemd.startBarDaemon "bar-daemon.service";
        };
        Service = {
          ExecStart = "${cfg.package}/bin/shelllist run";
          Restart = "on-failure";
          RestartSec = "2s";
          Environment = environment;
        };
        Install.WantedBy = [ cfg.systemd.target ];
      };

      bar-daemon = lib.mkIf cfg.systemd.startBarDaemon {
        Unit = {
          Description = "Quickshell bar status and policy service";
          PartOf = [ cfg.systemd.target ];
          After = [ cfg.systemd.target "dbus.service" "pipewire.service" "wireplumber.service" ];
        };
        Service = {
          Type = "dbus";
          BusName = "org.laufan.BarDaemon";
          ExecStart = "${cfg.package}/bin/bar-daemon daemon";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ cfg.systemd.target ];
      };
    };
  };
}
