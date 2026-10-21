# Shelllist Updates

Updates is a read-only application in the **real system tray**, not a dedicated
bar status item. Open the ellipsis → Shelllist Updates → Activate application,
its native **Open update history** menu, the desktop launcher, or:

```
shelllist updates open
shelllist updates run RUN_ID
```

The existing `update-logs` global shortcut now opens this viewer. The application
is lazy-loaded and shares Shelllist's chooser/navigation components. Enter/Right
inspect a run; arrows browse without executing updates. Alt+V reads the worker
journal, Alt+C copies its recorded summary through the clipboard daemon, and
Alt+A returns from a deep link to all recent runs. F5 refreshes reads only. Pages
append on scroll; Load more is also available. No Apply, Retry, Reboot, Approve,
Rollback or updater shutdown action is exposed.

## Data and semantics

`update-daemon` publishes versioned, atomic `history/RUN_ID.json` records beside
its current per-lane status. Records retain operation, phase, process identity,
timestamps, exit status, bounded diagnostics and before/after tool versions when
known. Actual changes are captured independently of the tool's last activation
phase: a subsequent no-change check is not another successful installation.
System readiness, queuing, boot staging and activation remain distinct. A
historical result never establishes the currently booted system.

The first release covers **worker-managed system and AI-tool jobs**. Manual
rebuilds, control-only rollback/resume commands and pre-installation runs do not
have a fabricated history. Detailed system generation/baseline diagnostics remain
available through `update-worker status --json`. Missing, unreadable and invalid
records are explicit, not an empty “everything current” result.

The producer retains up to 1,000 completed/abandoned records for 90 days and
never prunes a live job. Pruning occurs on terminal publication. History writes
are display projection writes: a failure cannot roll back, retry or relabel an
already verified deployment. They are reported separately in the worker journal.

`bar-daemon` provides `updates.queryHistory` (query/cursor/run_id/limit) and
`updates.readLog` (run_id). History pages are capped at 100 records/128 KiB, with
revision-fenced cursors. Reads are off the render thread and admission/deadline
bounded. This implementation deliberately uses the bounded producer catalog
rather than maintaining a duplicate SQL update index; notification persistence
already uses SQLite. The filesystem watcher also reconciles missed events.

Journal reads use the recorded boot ID/PID/time window, at most 100 lines/32 KiB
and a three-second deadline. They do not run a shell, follow a record-provided
path, request sudo, or grant additional journal access. Child-build output can be
recorded separately; missing entries are reported honestly. Copy and journal
responses retain their original target when the selection changes.

## Outcomes and notifications

The resident desktop backend owns one neutral `shelllist-updates` SNI item, using
ksni for the native menu and watcher re-registration. Active means the review app
is available, not that updates are running. Failure does not make the icon flash.
The tray item opens history even when everything is current. The launcher is the
fallback if no tray host exists.

- Meaningful activation/staging successes and new failures notify at normal
  urgency, using one Shelllist Updates identity. No-change checks are silent.
- Partial batches retain all component results. An unrelated successful tool
  cannot clear a different tool's incident. Identical failures do not notify on
  every retry; matching recovery permits a later recurrence to notify again.
- Deliberate rollback holds and explicit Control-C cancellation do not generate
  failure popups. Queued/ready intermediate phases remain in history.
- First import is silent except for still-unresolved problems. Subsequent login
  catch-up sends one summary rather than a backlog. Closely observed batches are
  also summarized. There is no timed nag/reminder loop.
- Native DND and per-app Silence apply normally. Silence suppresses popups, not
  retained records; ending DND never replays suppressed popups. Preferences remain
  in the existing notification center's **Shelllist Updates → App controls**.
- Live native notification activation opens the exact run; catch-up opens the
  collection. An expired run opens recent history with a notice. The current
  notification center intentionally has no historical sender-action reader.
- Native event keys and notification records commit in one SQLite transaction
  before publication. A restart/retry of the same delivery key cannot duplicate
  it, even after dismissal/deletion. Event keys outlive the source retention.
  Native server restart retires live action conversations rather than resurrecting
  old popups. Internal routes cannot be injected by an external Notify sender.
- SwayNC receives summaries through the standard protocol, with no unsafe or
  orphaned action buttons. The tray/launcher remains available. External Notify
  cannot guarantee durable idempotency after an ambiguous delivery acknowledgement;
  live external-backend acceptance is separate from native tests.

Historical failures remain failures: opening or dismissing one does not acknowledge
an update, change an incident's execution state, or authorize deployment. Current
status is shown separately. This initial viewer does not yet annotate every old
failed row with its later recovery relationship.

## Coordinated deployment and rollback

Build and deploy the corresponding **update-daemon, bar-daemon and shelllist**
revisions together. Install the Shelllist application package, not just its QML
configuration, so the desktop entry and icon are available. Restart the desktop
backend/UI after installation. No live deployment is performed by source tests.

The worker package's `notificationOwner` argument defaults to `"desktop"`; this
is embedded, not a caller-controlled environment variable. Old configurations
without the field deserialize as `legacy`. Desktop publication only consumes
records explicitly marked `desktop`; legacy jobs retain their old worker alerts.
The desktop never enables a second publisher merely because a worker is absent.
For staged migration set `notificationOwner = "legacy"` until the new desktop
backend is installed. Do not deploy the new desktop-owner worker alone.

`BAR_DAEMON_UPDATE_DESKTOP=0` disables the tray/publisher for rollback or headless
sessions. History reads remain available. Set the worker back to `legacy` as part
of the same rollback; disabling the publisher alone intentionally does not enable
a competing notifier. Restoring the old UI revision restores its standalone icon.
The durable ledger is additive and can be preserved across rollback.

The launcher executable is `shelllist` on the session service's PATH. If the user
service does not inherit the profile path, set `BAR_DAEMON_SHELLLIST` to the
installed absolute executable. Arguments are always separate; no command template
or record-provided executable is accepted. Journalctl is packaged in bar-daemon's
runtime PATH.

## Evidence

- Producer tests: distinct rapid runs, stage/current semantics, bounded decoder,
  genuine changes versus retained activation, and display-write failure isolation.
- Native tests: bounded/partial history, cursor validation, notification persistence
  and restart dedupe under DND, per-tool recovery/recurrence, deliberate holds,
  real SNI registration/menu/activation and watcher restart on a private D-Bus.
  The tray test uses a recording launcher, never the live updater.
- Qt tests: actual browse/detail/log keys, exact-run routes, stale/malformed replies,
  retained rows, close fencing and absence of the standalone bar update item.

Live compositor focus/placement, a human accessibility review, performance
measurements, and real SwayNC integration are not certified by these fixtures.
No system update, reboot or privileged deployment is needed for these tests.

## Design references

[GNOME notification guidance](https://developer.gnome.org/hig/patterns/feedback/notifications.html),
[desktop notification protocol](https://specifications.freedesktop.org/notification-spec/latest/protocol.html),
[urgency](https://specifications.freedesktop.org/notification-spec/latest/urgency-levels.html),
and [StatusNotifierItem](https://www.freedesktop.org/wiki/Specifications/StatusNotifierItem/StatusNotifierItem/).
The reviewed HTML proposal is `shelllist-update-center-plan.html` in the parent
Projects directory; this document records the implemented first-release scope.
