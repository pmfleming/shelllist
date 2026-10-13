# Surface catalog (P7.1)

`surface-catalog.json` is the build-time source of surface identity/order, display
name/icon, controller loading policy, resident-state requirements, and optional
Home Manager shortcut defaults. It is not a controller/plugin registry or a
runtime settings file.

## Consumers and compatibility

- `tools/generate-surface-catalog.py` emits `shell/SurfaceCatalog.generated.js`.
  Regenerate with `python3 tools/generate-surface-catalog.py`; CI checks freshness
  with `--check`. No runtime JSON I/O is added.
- `SurfaceRegistry.qml` uses the descriptors, default surface, eager-loading set,
  and notification residency flag. All twelve controller/content factories remain
  explicitly typed QML. Wi-Fi and Bluetooth still load eagerly for status/prompts;
  other controllers/content remain lazy, and opened surfaces stay warm. Shared
  notification state remains resident before its chooser is opened.
- `SurfaceShortcuts.qml` registers `shelllist:<id>` with description
  `Toggle Shelllist <name>` and routes activation to the existing host toggle path.
  Registration does not load the target surface. Non-surface actions (shell,
  update logs, volume, brightness, etc.) remain explicit, outside this catalog.
- `nix/surface-catalog.nix` validates the JSON during Nix evaluation. `flake.nix`
  derives the CLI help, accepted/direct surface IDs and default from it. Clipboard
  keeps its separate settings-command branch. IPC method names/arguments and
  `listSurfaces`' ordered `{id,name,icon}` array are unchanged.
- `nix/home-manager.nix` derives optional surface shortcut options and bindings.
  Existing notification/audio/media/tray option names, defaults and null-disable
  behavior are retained. `updateLogsShortcut` remains a separate action option.

Generated metadata is read-only by convention. Each registry obtains a fresh
mutable loading map; no controller state is stored in the JS library.

## Schema and additions

Version 1 requires a unique safe kebab-case `id`, nonempty `name` and `icon`,
`loading` (`eager` or `lazy`), `resident_state` (null or the explicitly implemented
`notifications` owner), and `home_manager_shortcut` (null or
`{option, default, description}`). A shortcut default can be null. The root
`default_surface` must be registered. IDs may not shadow host/effect commands;
shortcut option names/defaults must not collide, including with update logs.

Adding a surface requires updating the catalog **and** its typed factory, then
regenerating. Unsupported resident-state kinds are rejected until an explicit
owner is implemented. Native tests exercise every catalog controller/content
factory and shortcut, so a catalog-only addition is not considered complete.
Update the intentional twelve-surface compatibility expectations when approving
an addition. No factory source URL or effect dispatch is generated from strings.

## Tests and limits

- Python schema/generator tests inject unsafe/duplicate identities, unknown state
  policies, shortcut conflicts and stale/missing/hand-edited output.
- `tests/surface-catalog.nix` evaluates the real Home Manager module using minimal
  host-option fixtures: defaults, overrides, null-disable, disabled program and
  disabled compositor. It also checks Nix-side rejection.
- Native Qt tests cover all twelve controller/content factories and shortcut
  activations, unchanged descriptors, independent lazy state, resident
  notifications, invalid IDs, and queued/already-loaded notification/weather deep
  links. Only daemon transports and compositor registration are mocked.
- `checks.<system>.surfaceCatalog` enforces generation/schema/module checks;
  `surfaceCli` executes the actual packaged CLI with fake desktop/clipboard entry
  points for every surface/action form, floating/default/list/help paths, invalid
  input, rejection, and clipboard settings. It never starts a real host or daemon.

These checks do not claim live compositor shortcut delivery, deployed process
recovery, or completion of P7.2–P7.4. Screen polling and request/effect policy are
unchanged by this stage.
