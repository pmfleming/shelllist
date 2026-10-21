# Shelllist Updates

Updates is a read-only application in the **real system tray**, not a dedicated
bar status item. Open the ellipsis → Shelllist Updates → Activate application,
its native **Open update history** menu, the desktop launcher, or:

```
shelllist updates open
shelllist updates run RUN_ID
```

The existing `update-logs` global shortcut now opens this viewer. The application
is lazy-loaded and shares Shelllist's chooser/navigation components. A pinned
**Now** result opens the current-state inspector; the remaining results are runs.
Enter/Right inspects; arrows browse without executing updates. Alt+V reads or
refreshes the run's log (worker journal or private rebuild log); failed/partial
runs also load it automatically when inspected. Alt+C copies a readable bug-report
summary through the clipboard daemon. **Copy run JSON** and **Copy run log** are
separate commands under More (Alt+M). Alt+A returns from a deep link to all recent
runs. F5 refreshes history reads only. Pages
append on scroll; Load more is also available. No Apply, Retry, Reboot, Approve,
Rollback or updater shutdown action is exposed.

History rows retain catalog chronology and use distinct outcome icons with readable
outcome/lane labels and component change/failure counts. Counts describe loaded
versus matching retained runs, not the size of the first page alone. Passive
**Today / This week / This month / Older** headers use local calendar boundaries;
they are not selectable runs or new Tab stops. Timestamps show Today/Yesterday
and a clock, or a date for older records. The list footer carries history coverage
once, rather than repeating it in each run's details.

Details distinguish recorded job status from outcome, translate operation/phase
identifiers, explain known exit codes, and show duration. Live elapsed time ticks
only while the viewer is active; interrupted runs never acquire a fabricated
finish time or keep accumulating elapsed time. Partial catalog diagnostics are
warnings alongside readable records, not a total-history outage. The current
API caps and joins diagnostics, so the UI deliberately does not infer an exact
unreadable-record count. Log reads have their own loading/error state inside the
Run log card and cannot replace history feedback or another run's log.

**Now** stays above history even during search or history failure, and is excluded
from run counts. It uses only the live `barController.updates` snapshot, never a
historical run as proof of current deployment. System, AI tools and stale-check
cards show the latest worker state/phase and observation time. Missing jobs stay
“Not reported”, not fabricated idle/success. A last worker run is not necessarily
a successful check; authoritative last-check times still need backend support.
The deferred candidate card shows age, automatic/manual-approval policy, revision,
base hash and system path. A completed staging job is labelled as a **last run**
observation, not proof that a reboot is still pending. Comparing booted/current/
staged generations, schedules and installed tool inventory remains future work.

Components use shared read-only label/value rows grouped into Failed, Changed and
Unchanged, with counts. Failures take precedence in grouping; a component that
changed before failing still contributes to the overall change count. NixOS store
paths are shortened for display only. Each component has an explicit Copy command
with full before/after paths and diagnostics; summaries and JSON also retain them.
These values and groups add no editable Tab stops.

Logs use monospace plain text with error:/warning: line colours and an explicit
worker-journal/rebuild-file source. The rendered tail is bounded to 100 lines,
including multiline journal entries, and the limit/truncation note is separate
from raw copied output. Up to eight successful or failed log reads are cached for
one viewer invocation. A pending read retains its run identity; after it finishes,
the latest inspected failed/partial run may start its own read. Browsing back or
refreshing history does not automatically retry cached failures; Alt+V explicitly
retries. A changed phase/completion invalidates the cached log, so a running
snapshot cannot hide a later terminal failure. Closing clears the cache and
fences late replies. Copy failures have separate feedback and cannot overwrite
history diagnostics.

## Data and semantics

`update-daemon` publishes versioned, atomic `history/RUN_ID.json` records beside
its current per-lane status. Records retain operation, phase, process identity,
timestamps, exit status, bounded diagnostics and before/after tool versions when
known. Actual changes are captured independently of the tool's last activation
phase: a subsequent no-change check is not another successful installation.
System readiness, queuing, boot staging and activation remain distinct. A
historical result never establishes the currently booted system.

History covers **worker-managed system/AI-tool jobs and the existing manual
`rebuild` wrapper's reports**. The latter are read from
`$XDG_STATE_HOME/nixos-rebuild` (default `~/.local/state/nixos-rebuild`), including
`history.jsonl` and live `.run.json` markers. `BAR_DAEMON_REBUILD_STATE_DIR` can
select another producer directory. Reports stay private; nothing is copied into
root-owned update state. A rebuild that activated a system but failed during a
follow-up step is a partial outcome, not a claim that activation failed.
Terminal publication wins over a not-yet-removed running marker; abandoned markers
remain completion-unknown until the producer supplies its final report.

Direct `nixos-rebuild` calls outside this reporting wrapper, control-only
rollback/resume commands and unrecorded operations do not acquire fabricated
history. Existing recorded manual runs can be imported, but old successful runs
never trigger a notification backlog. Detailed system generation/baseline diagnostics remain
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
Both sources invalidate open history views; ordinary rebuild log chatter does not
trigger repeated catalog scans. The combined view retains up to 1,000 terminal
runs over 90 days without deleting the manual producer's files.

Worker journal reads use the recorded boot ID/PID/time window. Manual log reads
use only validated rebuild filenames inside the user-owned ledger directory:
no arbitrary path, symlink, non-regular file or group/world-writable source is
accepted. No worker PID/boot identity is invented for completed manual records.
Both paths return at most 100 lines/32 KiB with a three-second log-read deadline,
without running a shell, requesting sudo or granting journal access. Child-build
output can be recorded separately; missing entries are reported honestly. Copy
and log responses retain their original target when selection changes.

## Outcomes and notifications

The resident desktop backend owns one neutral `shelllist-updates` SNI item, using
ksni for the native menu and watcher re-registration. Active means the review app
is available, not that updates are running. Failure does not make the icon flash.
The tray item opens history even when everything is current. The launcher is the
fallback if no tray host exists.

- Meaningful activation/staging successes and new failures notify at normal
  urgency, using one Shelllist Updates identity. Automatic no-change checks are
  silent; an explicit manual rebuild's completion notifies even if the system
  stayed unchanged, with wording that makes that distinction clear.
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

For read-only diagnosis, `bar-daemon debug update-history` queries the same
bounded catalog without launching the UI, sending a notification or performing an
update. The UI takes protocol/version from its generated backend contract rather
than a panel-local constant.

Selecting a tray row opens the generic tray inspector, **not** that application's
window or history. Use its filled Activate application button (**Alt+A**) or the
native Open update history menu. `shelllist updates open` bypasses that inspector.
A blank tray inspector alone does not establish whether history exists.

## Evidence

- Producer tests: distinct rapid runs, stage/current semantics, bounded decoder,
  genuine changes versus retained activation, and display-write failure isolation.
- Native tests: bounded/partial history, cursor validation, notification persistence
  and restart dedupe under DND, per-tool recovery/recurrence, deliberate holds,
  real SNI registration/menu/activation and watcher restart on a private D-Bus.
  The tray test uses a recording launcher, never the live updater. Manual-source
  tests cover real report shapes, activation versus follow-up failure, private
  log bounds/path rejection, running/final races, watcher filtering, silent import
  and subsequent native failure/success delivery without restart replay.
- Qt tests: actual browse/detail/log keys, exact-run routes, stale/malformed replies,
  retained rows, close fencing and absence of the standalone bar update item.
  Readability coverage includes catalog ordering across passive date headers,
  loaded/total counts, component summaries, status versus outcome, live duration
  without reads/focus changes, partial-history publication and run-local log errors.
  Current-state/history separation, candidate metadata, automatic log queuing and
  failure caching, plain-text bounded log rendering, readable/JSON/raw-log copies,
  and the component's full-path pointer Copy route are also exercised.
  Replies use the generated protocol version, preventing a matching hardcoded
  test stub from concealing a production protocol mismatch.

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
