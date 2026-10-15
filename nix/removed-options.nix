{ lib, ... }:
{
  # Fail with an actionable migration path instead of silently losing policy.
  imports = map (entry: lib.mkRemovedOptionModule
    ([ "programs" "shelllist" ] ++ entry.path) entry.message) [
    { path = [ "systemd" "startBarDaemon" ]; message = "Import bar-daemon.homeManagerModules.default or nixosModules.default and enable services.bar-daemon explicitly."; }
    { path = [ "displays" "enable" ]; message = "Use services.bar-daemon.displays.enable in the daemon module."; }
    { path = [ "media" "youtubeMetadata" "enable" ]; message = "Use services.bar-daemon.media.youtubeMetadata.enable in the daemon module."; }
    { path = [ "suspend" "enable" ]; message = "Use services.bar-daemon.suspend.enable in the daemon Home Manager module."; }
    { path = [ "sleep" "enable" ]; message = "Use services.bar-daemon.suspend.enable in the daemon Home Manager module."; }
    { path = [ "discovery" ]; message = "Import nm-daemon.nixosModules.discovery and configure services.nm-daemon.discovery."; }
    { path = [ "resources" ]; message = "Import app-daemon.nixosModules.default and configure services.app-daemon.resources.enableRaplAccess."; }
  ];
}
