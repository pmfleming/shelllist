# T3 Code login launch — 2026-11-11

The reported login launch used the wrong T3 Code version and lacked compositor
placement. This was a host configuration repair; no panel or daemon API changed.

## Evidence

- `~/.config/autostart/t3code.desktop` contained `Exec=t3code-desktop %U`.
  The generated `app-t3code@autostart.service` resolved that bare executable to
  `/run/current-system/sw/bin/t3code-desktop`, whose real path was the Nix
  `t3code-0.0.33` package. The interactive shell instead resolved the same name
  to the vendor-aware launcher. Its PATH was not evidence of what systemd ran.
- The November 11 login journal records an Alpha window with class `t3code`
  at 08:46 and its closure at 08:49. PID 1851 logged its data directory as
  `~/.t3/userdata`, failed to restore saved window bounds, and reported an
  unknown IndexedDB schema followed by database recovery/deletion.
- The manually relaunched process, PID 3966, used vendor `t3code-0.1.8`, class
  `com.t3tools.T3Code`, and Chromium user data under `~/.config/t3code-v2`.
  The user reported that this launch restored the session. This investigation
  did not inspect or modify session databases or establish the extent of the
  Alpha browser-storage recovery.
- Hyprland's Code workspace rule omitted both T3 classes. Shelllist's category
  placement applies to its own launch transactions, not direct XDG autostart.

## Applied repair

- The existing, user-owned `t3code.desktop` autostart entry now uses the absolute
  `/var/lib/nixos-ai-tools/vendor/t3/current/bin/t3code-desktop` command. It
  follows the independently updated vendor profile without resolving the old
  system fallback. The display name and startup class now describe Beta.
  The desktop ID and enabled state remain unchanged, preserving the Shelllist
  autostart switch's ownership. This host-specific entry requires the vendor
  profile to remain installed; it deliberately has no Alpha fallback.
- `/etc/nixos/config/hypr/hyprland.lua` now routes the exact classes `t3code` and
  `com.t3tools.T3Code` to `3 silent` for session-owned launches too.
- Applied the identical five-line rule to the active rendered configuration,
  stored it as a GC-rooted Nix store file, and atomically updated the active
  configuration symlink. The next normal Home Manager deployment regenerates
  the rule from the edited source. No system rebuild was run.
- Reloaded Hyprland with `config-only` and regenerated user systemd units.
  Did not start the autostart service, restart T3 Code, or log out.

Original startup entry, source/rendered configs, original symlink destination,
and the temporary active-config GC root are retained under
`~/.local/state/shelllist-repairs/t3-autostart-2026-11-11/`.

## Validation and limits

- The regenerated unit's `ExecStart` is the absolute vendor-profile command.
  That wrapper resolves to the exact executable of the running Beta process.
- Existing Hyprland shortcut-registration checks pass against the repaired
  rendered config; compositor reload succeeds and `hyprctl configerrors` is
  empty. Source and active configuration contain the same placement rule.
- The T3 process remains PID 3966 on workspace 3 after the repair.
- Actual next-login startup and session restoration remain untested. The
  already-open window's workspace is not evidence of a new-window placement
  test. A logout/login is required to close that acceptance gap.
