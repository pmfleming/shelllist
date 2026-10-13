# The JSON catalog is also read directly at Nix evaluation time. IDs feed shell
# case patterns, so validate them here as well as in the generation/freshness gate.
{ lib, catalog ? builtins.fromJSON (builtins.readFile ../contracts/surface-catalog.json) }:
let
  keysAre = value: keys:
    builtins.isAttrs value && builtins.attrNames value == lib.sort builtins.lessThan keys;
  nonempty = value: builtins.isString value && builtins.match ".*[^[:space:]].*" value != null
    && builtins.match ".*[[:cntrl:]].*" value == null;
  reserved = [
    "open" "toggle" "floating" "hide" "quit" "status" "responsiveness"
    "list" "daemon" "run" "help" "shell" "update-logs" "volume-up"
    "volume-down" "volume-mute" "microphone-mute" "brightness-up" "brightness-down"
  ];
  validShortcut = shortcut:
    shortcut == null || (
      keysAre shortcut [ "option" "default" "description" ]
      && builtins.isString shortcut.option
      && builtins.match "[a-z][A-Za-z0-9]*Shortcut" shortcut.option != null
      && shortcut.option != "updateLogsShortcut"
      && nonempty shortcut.description
      && (shortcut.default == null || (nonempty shortcut.default
        && builtins.length (lib.splitString "," shortcut.default) == 2
        && shortcut.default != "SUPER SHIFT, U"))
    );
  validSurface = surface:
    keysAre surface [ "id" "name" "icon" "loading" "resident_state" "home_manager_shortcut" ]
    && builtins.isString surface.id
    && builtins.match "[a-z][a-z0-9]*(-[a-z0-9]+)*" surface.id != null
    && !(builtins.elem surface.id reserved)
    && nonempty surface.name && nonempty surface.icon
    && builtins.elem surface.loading [ "eager" "lazy" ]
    && builtins.elem surface.resident_state [ null "notifications" ]
    && validShortcut surface.home_manager_shortcut;
  ids = map (surface: surface.id) catalog.surfaces;
  withShortcuts = builtins.filter (surface: surface.home_manager_shortcut != null) catalog.surfaces;
  options = map (surface: surface.home_manager_shortcut.option) withShortcuts;
  defaults = builtins.filter (value: value != null) (map (surface: surface.home_manager_shortcut.default) withShortcuts);
  unique = values: builtins.length values == builtins.length (lib.unique values);
in
assert lib.assertMsg (keysAre catalog [ "schema_version" "default_surface" "surfaces" ]) "Invalid surface catalog keys";
assert lib.assertMsg (builtins.isInt catalog.schema_version && catalog.schema_version == 1) "Unsupported surface catalog version";
assert lib.assertMsg (builtins.isList catalog.surfaces && catalog.surfaces != [] && builtins.all validSurface catalog.surfaces) "Invalid surface catalog entry";
assert lib.assertMsg (unique ids && unique options && unique defaults) "Duplicate surface/shortcut metadata";
assert lib.assertMsg (builtins.isString catalog.default_surface && builtins.elem catalog.default_surface ids) "Unregistered default surface";
{
  inherit ids withShortcuts;
  entries = catalog.surfaces;
  defaultId = catalog.default_surface;
  defaultName = (builtins.head (builtins.filter (surface: surface.id == catalog.default_surface) catalog.surfaces)).name;
  # Clipboard retains its explicit pause/private/resume/kept command branch.
  directIds = builtins.filter (id: id != "clipboard") ids;
}
