# Captive-portal ownership migration

## Four delivery stages

1. `nm-daemon` issues validated launch intents. Identity comes from system-bus
   GUID + NM owner + active-object path + profile UUID, not a frontend SSID/key.
   Automatic requests must match this transport owner's completed successful
   connect on the currently captive primary connection.
2. Rust owns durable deduplication, fallback rotation and prepare/claim/complete.
   A private runtime ledger reserves an automatic attempt before returning it;
   a lost reply, UI disappearance, daemon restart or uncertain browser result
   never silently permits another automatic attempt. Claims are single-use,
   owner-bound and expire after 10 seconds. Claim uses uncached, owner-fenced NM
   property reads. Manual retries are explicit. The ledger is bounded at 1,024
   episodes / 2 MiB and fails closed instead of evicting uncertain attempts.
3. `portal-launcher/` is a **frontend-owned** Rust effect adapter. It consumes the
   shared `shelllist-hyprland` native IPC transport and parses compositor replies
   in Rust. It only executes a supplied URL and UI workspace/focus intent, with a
   private browser profile, nonblocking execution lock and bounded observation.
4. QML consumes prepare/claim/complete and rejects stale/expired replies. The
   Wi-Fi Alt+I command and bar fallback use the same transaction. Removed JS
   episode/network/context policy and the shell wrapper's persistence, fallback
   rotation and raw hyprctl/jq parsing. No legacy launch path remains installed.

## Preserved boundaries and safety

The daemon never opens a browser or focuses a window. Workspace intent, status
copy and in-flight presentation stay in QML. Keyboard navigation never launches
anything; Sign in remains an Alt+letter action, not a field Tab stop. No field
save model changed. The existing Chromium isolation/network flags are retained.
Each claimed intent submits its URL even with an existing portal window; merely
focusing the previous page would discard an explicit fallback choice.

Only plain HTTP NM probes are selected, preserving the old portal rule; unsafe,
credential-bearing, missing and HTTPS probes use NeverSSL. Explicit fallback
rotates through the existing Apple/Microsoft/GNOME URLs in Rust, per episode.
UI/browser success is not authentication success; only NM can report full access.

`opened` means a new browser window and focus were observed, `failed` means no
browser effect started, and `uncertain` means an effect may have occurred. Missing
helper output/crashes are uncertain. No outcome re-enables an automatic attempt.
Normal RPCs are not subscriptions and are not passed to cancellation APIs.
Transport recovery only restores reads; it does not replay portal commands.

The active object is conservatively one episode even if connectivity oscillates.
A primary/network change before claim is rejected. Network state can still change
between the final claim read and browser execution; making these separate
process/system effects atomic is not possible. On upgrade, retained old shell
helper episode/fallback files are ignored (not imported as authority). The browser
profile may be reused; the enclosing directory is tightened to private ownership.

## Validation

- Rust policy regressions cover proof/identity, NM restarts and reconnects,
  unsafe URLs, reservation and claim loss, owner/deadline/network fencing,
  overlapping requests, manual fallback rotation, completion and persistence
  failure/corruption. Existing networking tests stay enabled.
- Native helper tests cover argument safety, URL/deadline validation, typed window
  parsing and actual mock Unix-socket move/focus dispatch with compatibility
  fallback. No real compositor/browser effects are performed.
- `tests/qml/tst_wifi_portal.qml` drives actual Alt+I and navigation, prepare/claim
  ordering, daemon denial, overlap, expiry, stale responses, process failures,
  unknown outcomes, transport loss/UI destruction and the bar fallback route.
- Generated protocol bindings and nm API fixtures cover all three new commands.
- Coordinated Nix validation captures current sibling worktrees with the same
  shared framework, including the UI helper's path dependency.

Final code validation: 301 Qt passes, 125 nm-daemon library passes (three existing
opt-in tests ignored), four native launcher tests, Rustfmt/Clippy, strict QML lint,
protocol/boundary checks and the coordinated sibling Nix gate passed. The initial
parallel cold build hit the existing chooser-memory timing failure; the full gate
passed with serialized Nix jobs, without disabling tests or changing timeouts.
An offscreen real-Quickshell probe also confirmed asynchronous exec failure does
not emit `exited`; the adapter now handles that no-effect path explicitly and has
a Qt regression for it.

Live hotspot/Chromium/Hyprland acceptance is separate and has not been performed.
No daemon/service was activated or restarted by this migration.
