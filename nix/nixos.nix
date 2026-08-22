self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.shelllist;
  system = pkgs.stdenv.hostPlatform.system;
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

    resources.enableRaplAccess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Grant read-only access to Intel RAPL energy counters so the unprivileged
        application daemon can estimate per-application power usage.
      '';
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
    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];
    security.polkit.enable = true;
    systemd.packages = [ cfg.package ];

    services.udev.extraRules = lib.mkIf cfg.resources.enableRaplAccess ''
      ACTION=="add|change", SUBSYSTEM=="powercap", KERNEL=="intel-rapl:*", TEST=="energy_uj", RUN+="${pkgs.coreutils}/bin/chmod 0444 /sys%p/energy_uj"
    '';

    system.activationScripts.shelllistRaplAccess =
      lib.mkIf cfg.resources.enableRaplAccess {
        text = ''
          for energy_file in /sys/class/powercap/intel-rapl:*/energy_uj; do
            if [ -e "$energy_file" ]; then
              ${pkgs.coreutils}/bin/chmod 0444 "$energy_file"
            fi
          done
        '';
      };

    systemd.user.services.shelllist = lib.mkIf cfg.systemd.enable {
      description = "Shelllist desktop action center and top bar";
      wantedBy = [ cfg.systemd.target ];
      partOf = [ cfg.systemd.target ];
      after = [ cfg.systemd.target ] ++ lib.optional cfg.systemd.startBarDaemon "bar-daemon.service";
      environment = cfg.systemd.environment;
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/shelllist run";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };

    systemd.user.services.bar-daemon = lib.mkIf (cfg.systemd.enable && cfg.systemd.startBarDaemon) {
      description = "Quickshell bar status and policy service";
      wantedBy = [ cfg.systemd.target ];
      partOf = [ cfg.systemd.target ];
      after = [ cfg.systemd.target "dbus.service" "pipewire.service" "wireplumber.service" ];
      before = [ "swaync.service" ];
      conflicts = [ "swaync.service" ];
      environment.BAR_DAEMON_NOTIFICATION_BACKEND = "native";
      serviceConfig = {
        Type = "dbus";
        BusName = "org.laufan.BarDaemon";
        ExecStart = "${cfg.package}/bin/bar-daemon daemon";
        Restart = "on-failure";
        RestartSec = "2s";
      };
    };
  };
}
