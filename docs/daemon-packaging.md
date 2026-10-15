# Independent UI and daemon deployment

Shelllist's default package is the UI application, not a symlink union with
bar-daemon. Its modules install/start only Shelllist and configure UI shortcuts.
Daemon clients remain in the wrapper's runtime PATH for the JSONL bridges. This
is a client-adapter dependency, not permission for the UI to configure or own the
backend. Daemon binaries currently share packages with their clients; this does
not remove them from the transitive closure.

Consumers must compose the following separately:

- `bar-daemon.homeManagerModules.default`: `services.bar-daemon.enable`,
  `displays.enable`, `media.youtubeMetadata.enable`, `suspend.enable`.
- `bar-daemon.nixosModules.default`: `services.bar-daemon.batteryHelper.enable`
  for privileged battery integration. Use its session `enable` only if session
  startup is owned by NixOS instead of Home Manager, never both.
- `bar-daemon.nixosModules.location-timezone`: location-only policy and service.
- `app-daemon.nixosModules.default`: `services.app-daemon.resources.enableRaplAccess`.
- `nm-daemon.nixosModules.discovery`: `services.nm-daemon.discovery`.

Install/enable the app, Bluetooth, clipboard and network daemons independently as
before. Preserve existing host preferences rather than opting into new policy as
an incidental effect of enabling a UI. Configure bar-daemon's notify-ready idle
integration with Home Manager; lock/DPMS listener values remain host choices.

Old `programs.shelllist` policy options fail with migration instructions rather
than silently ignoring user policy. Shelllist can be stopped or disabled without
stopping daemon policy. On reconnect the UI reads snapshots; it must not replay
uncertain mutations. UI transient drafts, focus and interactive browser/scanner
placement remain frontend-owned.
