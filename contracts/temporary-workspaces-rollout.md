# Coordinated workspace rollout

Build the current local graph with the repository's `local-build` entrypoint.
Shelllist, app-daemon, bar-daemon and daemon-framework must come from the same
captured graph. Do not revive historical local-input lock pins. The generated
bindings are produced from the Rust daemons' registries.

The app service orders startup after and wants bar-daemon. Workspace policy and
shortcut CLI are Rust; Shelllist QML only renders state and sends commands.
The four native Hyprland configuration bindings execute:

| Shortcut | Command |
| --- | --- |
| Super+Ctrl+N | `bar-daemon workspace create` |
| Shift+Super+Q | `bar-daemon workspace close` |
| Super+Ctrl+PageDown | `bar-daemon workspace next` |
| Super+Ctrl+PageUp | `bar-daemon workspace previous` |

Super+Q retains normal focused-window close. The new close command has no force
flag. Its target is captured inside the serialized daemon; the CLI does not
evaluate the current workspace or retry timed-out effects. Native Lua contains
only binding declarations, with no workspace policy or helper script.

To disable new allocation while investigating a rollout, set
`SHELLLIST_TEMPORARY_WORKSPACES=0` in both app-daemon and bar-daemon service
environments and restart those services. The bar disables `+`, rejects creation
and retains observed ordinary workspaces. App default launches use the legacy
explicit-category/current-workspace routing; the saved v2 new-workspace preference is
preserved. Existing close, lookup and release guards remain active. Do not erase
runtime journals to recover from an unknown effect. On full downgrade, keep the
v2 settings and use the unchanged v1 settings file for the old daemon.

No service restart, compositor reload or system rebuild is performed merely by
committing this implementation. Stage evidence states which checks actually ran.
