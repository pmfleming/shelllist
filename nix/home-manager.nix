self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.shelllist;
  system = pkgs.stdenv.hostPlatform.system;
  environment = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.systemd.environment;
  managedHypridle = import ./hypridle-ready.nix config.services.hypridle.package;
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

    notificationsShortcut = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "SUPER SHIFT, N";
      description = "Hyprland modifiers and key for opening Notifications directly. Set null to disable.";
    };

    sleep.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.services.hypridle.enable && config.services.hypridle.package != null && cfg.systemd.enable && cfg.systemd.startBarDaemon;
      defaultText = lib.literalExpression "services.hypridle.enable && services.hypridle.package != null && programs.shelllist.systemd.enable && programs.shelllist.systemd.startBarDaemon";
      description = ''
        Let Battery & Power manage hypridle's automatic sleep timeout with shared
        or separate battery/AC profiles. Preserves lock and DPMS listeners and
        replaces simple systemctl/loginctl sleep listeners. Custom sleep scripts
        or source includes must be removed from the base hypridle configuration.
        Timed hibernation also requires the updated system bar-battery-helper.
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
    home.packages = [ cfg.package ];

    assertions = lib.optional cfg.sleep.enable {
      assertion = config.services.hypridle.enable && config.services.hypridle.package != null && cfg.systemd.enable && cfg.systemd.startBarDaemon;
      message = "Shelllist automatic sleep requires services.hypridle.enable and Shelllist's managed bar-daemon service.";
    };

    wayland.windowManager.hyprland.settings.bind = lib.mkIf
      (config.wayland.windowManager.hyprland.enable && cfg.notificationsShortcut != null)
      [ "${cfg.notificationsShortcut}, exec, ${cfg.package}/bin/shelllist notifications open" ];

    systemd.user.services = lib.mkIf cfg.systemd.enable {
      hypridle = lib.mkIf cfg.sleep.enable {
        Service = {
          Type = lib.mkForce "notify";
          NotifyAccess = "main";
          TimeoutStartSec = "8s";
          ExecStart = lib.mkForce "${cfg.package}/bin/bar-daemon idle --config ${lib.escapeShellArg "${config.xdg.configHome}/hypr/hypridle.conf"} --hypridle ${managedHypridle}/bin/hypridle";
        };
      };

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
          Before = [ "swaync.service" ];
          Conflicts = [ "swaync.service" ];
        };
        Service = {
          Type = "dbus";
          BusName = "org.laufan.BarDaemon";
          ExecStart = "${cfg.package}/bin/bar-daemon daemon";
          Environment = [ "BAR_DAEMON_NOTIFICATION_BACKEND=native" ]
            ++ lib.optional cfg.sleep.enable "BAR_DAEMON_IDLE_CONFIG=${config.xdg.configHome}/hypr/hypridle.conf";
          Restart = "on-failure";
          RestartSec = "2s";
        };
        Install.WantedBy = [ cfg.systemd.target ];
      };
    };
  };
}
