# Wi-Fi operation feedback and recovery

## Stable controls

Disabled commands stay visible and retain their geometry. Shared flat icon
buttons use a surface-appropriate disabled foreground, not the accent-fill
foreground on a transparent background. Their reduced opacity is independent of
filled-circle styling. The rendering regression covers light and dark themes.

Wi-Fi busy state covers conflicting mutations, not status/profile reads,
portal browser work or screenshots. Unknown request kinds remain exclusive.
Search/result browsing and the QR reader remain available. Refresh/F5 queues a
refresh during activation rather than racing a second scan. Profile, power,
connect and disconnect commands retain their acknowledgement/capability guards.
QR-start admission counts as a mutation just like ordinary connection admission.

A QR scanned during a conflicting mutation is parsed by the daemon for display
only. No passphrase is retained in QML for delayed replay. The user explicitly
rescans to join after the operation finishes. Duplicate scanner launches remain
blocked. Screenshot capture still protects modal/private input and prevents
concurrent captures, but does not disable network commands.

## Daemon authority

`nm-daemon` now reads NetworkManager's passive Connectivity property for ordinary
Wi-Fi status, shared subscription refreshes and post-activation details. It does
not synchronously probe the internet as part of completing a link operation.
An explicit `network.connectivity` diagnostic still requests a fresh probe.
Unknown internet access is neither failed activation nor permission to launch a
portal. Existing portal prepare/claim/completion guards remain; a later portal
verdict exposes manual Sign in if no automatic suggestion was available at link
completion.

The daemon records owner-scoped progress before emitting signals and retains
terminal connection results for five minutes. Its overall 240-second connect
budget includes queueing/alternate APs and requests cancellation on expiry.
The existing per-activation deadline and password/retry rules remain. Expiry is
not completion: task/admission guards stay live until the worker acknowledges.
Underlying blocking work may delay that acknowledgement; it is not force-killed
or reported as success. Disconnect retains its request/reply transport timeout.
See `nm-daemon/docs/wifi-operation-lifecycle.md` in the sibling checkout.

## Recovery commands

- **Alt+K — Check status:** read-only `operation.status` for the owned request.
- **Alt+X — Cancel:** remains available when a link is active but its operation
  has not finished, or when a QR join has no matching selected list row.
- **F5 / refresh:** same guarded, deferred refresh path.
- **Alt+Enter / QR button:** same scanner path, with duplicate/modal guards.

An event gap or 15-second recovery interval requests status. A status read has a
10-second UI reply deadline and stops automatic retries after three failed
reads; manual Check status remains usable. Only the matching owned terminal
result releases the pending connection. Unknown/malformed responses and late
replies cannot unlock a mutation or retire a newer read. A cancellation request
is not an acknowledgement; a daemon running verdict can make cancellation
retryable. Transport failure follows the existing separate recovery path and
never replays connection credentials or mutations. Background read messages do
not replace foreground connection progress.

All commands use shared navigation and remain outside field Tab traversal.
No new local editor/key model is introduced.

## Regression coverage

- `tests/qml/tst_material_feedback.qml`: painted disabled icons in light/dark
  themes and actual disabled/enabled pointer activation.
- `tests/qml/tst_wifi_operations.qml`: actual Alt+K/X/D, Alt+Enter, F5 and pointer
  routes; slow connect/disconnect, duplicate admission, delayed acknowledgements,
  screenshot overlap, missing events, timer expiry, read retry bounds, transport
  loss and malformed/late/foreign recovery replies.
- Daemon real D-Bus workflow: activation succeeds with unknown internet access
  without invoking a probe; the explicit probe remains functional.
- Daemon runtime: progress/terminal ownership, cancellation deadline retains live
  guards, and a completed link cannot be cancelled by a later deadline timer.

Validation: full Qt suite, strict QML lint, daemon library tests, nm-api contract
fixture and daemon-boundary checks. Hardware/compositor networking was not
changed or exercised; a live slow-DHCP/captive-portal acceptance run remains
separate. Use the repository's current-source `local-build` workflow to include
both checkout changes; persistent locks intentionally do not pin sibling daemons.
