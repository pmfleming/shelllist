# Evaluate the actual Home Manager module with a minimal host-option fixture.
# No Home Manager input, desktop process, service build or mutable machine state.
{ pkgs }:
let
  inherit (pkgs) lib;
  source = builtins.fromJSON (builtins.readFile ../contracts/surface-catalog.json);
  catalog = import ../nix/surface-catalog.nix { inherit lib; };
  package = pkgs.emptyDirectory;
  self = {
    packages.${pkgs.stdenv.hostPlatform.system}.default = package;
    inputs.bar-daemon.lib.mkManagedHypridle = value: value;
  };
  host = { ... }: {
    options = {
      home.packages = lib.mkOption { type = lib.types.listOf lib.types.package; default = []; };
      assertions = lib.mkOption { type = lib.types.listOf lib.types.attrs; default = []; };
      services.hypridle.enable = lib.mkOption { type = lib.types.bool; default = false; };
      services.hypridle.package = lib.mkOption { type = lib.types.nullOr lib.types.package; default = null; };
      systemd.user.services = lib.mkOption { type = lib.types.attrs; default = {}; };
      xdg.configHome = lib.mkOption { type = lib.types.str; default = "/home/test/.config"; };
      wayland.windowManager.hyprland = {
        enable = lib.mkOption { type = lib.types.bool; default = true; };
        settings.bind = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
      };
    };
  };
  evaluate = extra: (lib.evalModules {
    specialArgs = { inherit pkgs; };
    modules = [
      (import ../nix/home-manager.nix self)
      host
      { programs.shelllist = { enable = lib.mkDefault true; systemd.enable = false; }; }
      extra
    ];
  }).config;
  defaults = evaluate {};
  disabled = evaluate { programs.shelllist = { notificationsShortcut = null; updatesShortcut = null; audioShortcut = null; mediaShortcut = null; trayShortcut = null; updateLogsShortcut = null; }; };
  custom = evaluate { programs.shelllist = { audioShortcut = "SUPER, F8"; agendaShortcut = "SUPER, F9"; calendarShortcut = "SUPER, F10"; notificationsShortcut = null; }; };
  noCompositor = evaluate { wayland.windowManager.hyprland.enable = false; };
  noProgram = evaluate { programs.shelllist.enable = false; };
  bindings = config: config.wayland.windowManager.hyprland.settings.bind;
  expected = [
    "SUPER SHIFT, N, exec, ${package}/bin/shelllist notifications open"
    "SUPER, U, exec, ${package}/bin/shelllist updates open"
    "SUPER SHIFT, A, exec, ${package}/bin/shelllist audio open"
    "SUPER SHIFT, M, exec, ${package}/bin/shelllist media open"
    "SUPER SHIFT, T, exec, ${package}/bin/shelllist tray open"
    "SUPER SHIFT, U, global, shelllist:update-logs"
  ];
  rejects = value: !(builtins.tryEval (builtins.deepSeq (import ../nix/surface-catalog.nix { inherit lib; catalog = value; }) true)).success;
  replaceFirst = patch: source // { surfaces = [ ((builtins.head source.surfaces) // patch) ] ++ builtins.tail source.surfaces; };
in
assert catalog.ids == [ "applications" "wifi" "bluetooth" "clipboard" "displays" "battery" "agenda" "calendar" "notifications" "updates" "time-weather" "audio" "media" "tray" ];
assert catalog.defaultId == "applications" && catalog.defaultName == "Applications";
assert catalog.directIds == builtins.filter (id: id != "clipboard") catalog.ids;
assert bindings defaults == expected;
assert bindings disabled == [];
assert bindings noCompositor == [];
assert bindings noProgram == [];
assert builtins.elem "SUPER, F8, exec, ${package}/bin/shelllist audio open" (bindings custom);
assert !(builtins.elem (builtins.head expected) (bindings custom));
assert defaults.programs.shelllist.agendaShortcut == null;
assert defaults.programs.shelllist.calendarShortcut == null;
assert builtins.elem "SUPER, F9, exec, ${package}/bin/shelllist agenda open" (bindings custom);
assert builtins.elem "SUPER, F10, exec, ${package}/bin/shelllist calendar open" (bindings custom);
assert defaults.programs.shelllist.notificationsShortcut == "SUPER SHIFT, N";
assert defaults.programs.shelllist.updateLogsShortcut == "SUPER SHIFT, U";
assert defaults.programs.shelllist.updatesShortcut == "SUPER, U";
assert rejects (source // { schema_version = 2; });
assert rejects (source // { default_surface = "unknown"; });
assert rejects (replaceFirst { id = "run"; });
assert rejects (replaceFirst { id = "a|b"; });
assert rejects (replaceFirst { id = "wifi"; });
assert rejects (replaceFirst { loading = "unknown"; });
assert rejects (replaceFirst { resident_state = "unknown"; });
assert rejects (replaceFirst { home_manager_shortcut = (builtins.elemAt source.surfaces 8).home_manager_shortcut; });
true
