# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened by right-clicking the bar's Notifications group, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- a month calendar and selected-day agenda;
- persistent todos and source-health reporting.

Time/weather, notification previews and DND controls are not part of Activity.
Time & Weather and Notifications remain separate surfaces, reachable from the
bar, their commands and global shortcuts.

The bar bell opens Notifications; its right-click route opens Agenda. **Super+Shift+N** opens Notifications directly (installed by the Home Manager module when Hyprland is enabled; configurable with `programs.shelllist.notificationsShortcut`, or see the README binding). The search gear (Alt+Enter from search) opens Notification settings even when the list is empty. DND and its duration live there, not in a standalone power button. Saving duration while DND is off only selects the next duration; while on it restarts DND with that duration. “Until turned off” has no expiry. The switch and deadline show daemon-acknowledged state; failed writes offer retry.

Alt+S captures the complete visible Activity panel through `clip-daemon` and copies the image to the clipboard and clipboard history, just as in every other Shelllist surface.

Popup-visible notifications appear in up to three compact notification stacks per monitor. Normal server-default popups hide after five seconds without closing the live notification; it remains actionable in the center. Explicit client expiry, dismissal or sender closure makes a record read-only. Transient notifications are not retained in history. Server restart archives old conversations rather than reviving their actions. A stacked toast shows only its newest record and a count badge; its chevron opens that group in the separate Notifications callout. `shelllist notifications open|toggle` and the `notifications` global shortcut open the pane directly.

The surface uses one searchable list of individual notifications and a selected-message/reply inspector. The daemon supplies live and retained records without duplicates; there is no Active/History switch. Alt+S copies a screenshot through `clip-daemon`. Message actions, expandable bodies, inline replies and 15-minute snooze remain capability-dependent. Bulk dismissal retains history and also includes snoozed records. There is no history-deletion control.

When entered from Activity, Back or `Escape` restores Activity's calendar/detail state. Direct entry closes back to the desktop. The close button always closes. `F5` refreshes notifications. With the list focused, Up/Down selects an individual notification and Right/Left expands/collapses its details. Enter invokes its live default action, otherwise opens details without dismissing. The selected-message command strip works even while details are closed: Alt+O opens, Alt+D dismisses, Alt+Z snoozes, Alt+C copies text, Alt+R opens inline reply and Alt+J lists app actions. Commands are not hover-only. Only the exact `inline-reply` action opens the editor; ordinary app reply actions remain in the app menu. Search and replies have no printable single-key shortcuts.

Panels follow the [mandatory interaction contract](chooser-keyboard-workflow.md): Tab traverses editable fields, Enter/Tab saves, and Escape discards the current field edit. Todo entry uses Alt+A to add; Alt+D deletes the currently browsed todo. Alt+R sends the current reply; Alt+J opens other content actions. Saving a reply field retains its draft, rather than sending it.

Saved reply drafts are shared with toasts and retained in memory when views close, filters change or records update. Uncommitted panel-field edits are discarded on leaving. Only an acknowledged successful reply clears the matching draft; failures retain it for retry. Drafts are not persisted across Shelllist restarts.

## Ownership

Shelllist owns only:

- Hyprland/Quickshell layer-shell surfaces and monitor placement;
- month, agenda, todo, notification, and world-clock rendering;
- selected date, viewed month, focus, scroll, selected message and open tab;
- locale-aware labels and time formatting;
- animations and input;
- translation of user intent into `bar-api` calls.

`bar-daemon` owns durable data, source health, ordering, range bounds, mutations, retries, notification IDs, expiry, timed DND, snooze wakeups, grouping metadata, and SQLite history. Shelllist must be restartable without losing Activity state.

## Data and presentation flow

Activity uses the [shared anchored chooser geometry](chooser-geometry.md), not a
separate full-height right-edge panel. Its glance rail stays on the left while
Schedule expands to the right. Logical work-area bounds come from QScreen and
the event-driven daemon work-area stream; the frontend does not poll geometry.
The rail contains only the calendar/schedule summary, starting at the top.
Schedule expands its agenda/todo detail pane while preserving the rail.
`Ctrl+2` expands Schedule; the former `Ctrl+1` and `Ctrl+3` cross-surface shortcuts
are removed. Within Activity, `Escape` returns to the glance panel before closing
the surface. Opening Activity does not activate notification-history loading.

Time & Weather follows the same list/detail interaction as Wi-Fi and Bluetooth. The list combines configured weather locations and world clocks by timezone, showing city, current weather, and local time. `Right` expands the selected city. The detail pane has **Time** and **Weather** tabs; Time renders a world map that highlights every region sharing the selected current UTC offset and marks configured location coordinates, plus sun position, day length, and moon phase. Weather reuses the existing hourly, daily, and weather-metric presentation. The bar clock/date group opens this chooser directly.

Shelllist requests only a buffered range around the visible month. A compact `activity.changed` event schedules a debounced range refresh rather than carrying the full range in every event. Weather locations—including which location is home, labels, coordinates, and timezones—come entirely from `bar-daemon/activity.json`; no city is compiled into the UI. `bar-daemon` refreshes configured Open-Meteo locations concurrently at most every 15 minutes and retains each last successful forecast through transient failures.

In native notification mode, `bar-daemon` owns `org.freedesktop.Notifications` and publishes a bounded, recoverable snapshot containing only unsnoozed active records. That stream drives toasts and current action capabilities, not a second frontend history catalog. `notifications.queryHistory` supplies the unified center list: Rust merges live/persisted identities, orders rows and performs Unicode-lowercase literal substring search across app name, summary and body. Search covers the newest 5,000 persisted records plus unsnoozed live notifications, not merely loaded pages. Existing stored history is not pruned by this query limit.

The frontend requests visible pages of up to 50 records (also byte-bounded by the daemon). Opaque, expiring cursors bind pages to one daemon epoch, content revision and query. Changed/stale cursors trigger read-only refresh, never replay of mutations. A refresh stages pages through the previous oldest visible anchor and replaces the window atomically; it does not union old records into fresh results or infer deletions from intermediate active snapshots. This repairs missed/coalesced transient replacement/closure events, including after reconnect. Query generations supersede old reads; bounded ordinary RPCs may finish, but late replies cannot alter the new query. Search results can page just like the unfiltered list. Unsupported new APIs fail visibly without a JS catalog fallback.

One resident notification backend owns the shared state; the bar reads it rather than writing its own notification snapshots back. Equal snapshots, popup visibility and DND-only changes do not rebuild center rows or reload history. Reply drafts and operation acknowledgements remain keyed by notification ID plus creation time. Atomic replacements and page appends preserve stable selection, the top visible row/offset and active reply editor; the old window remains visible while a same-query replacement loads. Loading, unavailable, failed, empty and no-match states are distinct. See [history migration](reviews/notification-history-migration.md) for contract and validation details.

Toast stacks and legacy group links use the same grouping policy:

1. daemon-provided `group_key`;
2. desktop entry;
3. application name;
4. a final generic fallback.

The daemon captures the focused output as `source_monitor` when a notification arrives. Shelllist routes its active stack to that output when it still exists, otherwise to the focused output, then to the first available output. This routing is transient presentation policy; the source monitor remains daemon-owned record data.

Removal animation is presentation-only. Dismiss, clear-group, clear-all, snooze, action, and reply requests are sent to `bar-daemon`, which validates current state and publishes the resulting snapshot.

## Frontend contract

| File | Responsibility |
| --- | --- |
| `activity/ActivityApi.js` | Activity and notification method/stream registry |
| `activity/ActivityBackend.qml` | Calendar/todo/weather transport adapter |
| `activity/ActivityController.qml` | Ephemeral calendar range, selection, and presentation state |
| `activity/NotificationState.qml` | Shared live/history data and reply drafts |
| `activity/NotificationBackend.qml` | Notification requests, acknowledgements and stream adapter |
| `activity/NotificationController.qml` | Callout navigation, search and keyed notification model |
| `activity/NotificationContent.qml` | Standalone notification surface and return navigation |
| `activity/ActivityContent.qml` | Anchored calendar/agenda/todo composition |
| `activity/ActivityGlancePane.qml` | Calendar and schedule summary |
| `activity/TimeWeatherContent.qml` | City list and two-tab Time & Weather composition |
| `activity/TimeWeatherTimePane.qml` | Local time, sun position, moon, and timezone detail |
| `activity/ActivityWeatherPane.qml` | Reusable local weather and forecast detail |
| `activity/ActivitySchedulePane.qml` | Calendar, selected-day agenda, and todo detail |
| `activity/NotificationHistoryRow.qml` | Selected-message inspector |
| `bar/NotificationToastStack.qml` | Monitor-local active groups |
| `qml/Shelllist/Ui/NotificationPresentation.js` | Shared grouping, routing, and DND labels |
| `qml/Shelllist/Ui/RemovalAnimation.qml` | Shared transient dismissal animation |

`ActivityContent.qml` contains no filesystem, provider, subprocess, persistence, or notification-policy integration.

## Validation

The checked `bar-api` fixture validates `bar/BarApi.js` and `activity/ActivityApi.js` against the backend registry. Focused checks are:

```sh
node tests/check-notification-presentation.js qml/Shelllist/Ui/NotificationPresentation.js
tests/run-qml-tests.sh
nix build .#checks.x86_64-linux.barDaemonContract
nix flake check
```
