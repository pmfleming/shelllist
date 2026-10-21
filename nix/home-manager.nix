self:
{ config, lib, pkgs, ... }:
let
  cfg = config.programs.shelllist;
  surfaceCatalog = import ./surface-catalog.nix { inherit lib; };
  shortcutOptions = lib.listToAttrs (map (surface: {
    name = surface.home_manager_shortcut.option;
    value = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      inherit (surface.home_manager_shortcut) default description;
    };
  }) surfaceCatalog.withShortcuts);
  system = pkgs.stdenv.hostPlatform.system;
  environment = lib.mapAttrsToList (name: value: "${name}=${value}") cfg.systemd.environment;
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
    updateLogsShortcut = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "SUPER SHIFT, U";
      description = "Hyprland modifiers and key for reviewing recent updates. Set null to disable.";
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
  } // shortcutOptions;
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    wayland.windowManager.hyprland.settings.bind = lib.mkIf
      config.wayland.windowManager.hyprland.enable
      (lib.concatMap (surface:
        lib.optional (cfg.${surface.home_manager_shortcut.option} != null)
          "${cfg.${surface.home_manager_shortcut.option}}, exec, ${cfg.package}/bin/shelllist ${surface.id} open"
      ) surfaceCatalog.withShortcuts
      ++ lib.optional (cfg.updateLogsShortcut != null)
        "${cfg.updateLogsShortcut}, global, shelllist:update-logs");
    systemd.user.services.shelllist = lib.mkIf cfg.systemd.enable {
      Unit = {
        Description = "Shelllist desktop action center and top bar";
        PartOf = [ cfg.systemd.target ];
        After = [ cfg.systemd.target ];
      };
      Service = {
        ExecStart = "${cfg.package}/bin/shelllist run";
        Restart = "on-failure";
        RestartSec = "2s";
        Environment = environment;
      };
      Install.WantedBy = [ cfg.systemd.target ];
    };
  };
}
