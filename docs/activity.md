# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened by right-clicking the bar's Notifications group, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- a month calendar and selected-day agenda;
- persistent todos and source-health reporting.

Time/weather, notification previews and DND controls are not part of Activity.
Time & Weather and Notifications remain separate surfaces, reachable from the
bar, their commands and global shortcuts.

The bar bell opens Notifications; its right-click route opens Agenda. **Super+Shift+N** opens Notifications directly (installed by the Home Manager module when Hyprland is enabled; configurable with `programs.shelllist.notificationsShortcut`, or see the README binding). Changing the duration while DND is off only selects the next duration; while on it restarts DND with that duration. ∞ enables DND without an expiry.

Alt+S captures the complete visible Activity panel through `clip-daemon` and copies the image to the clipboard and clipboard history, just as in every other Shelllist surface.

Active notifications appear in up to three compact notification stacks per monitor. A stacked toast shows only its newest record and a count badge; its chevron opens that group in the separate Notifications callout. `shelllist notifications open|toggle` and the `notifications` global shortcut open the pane directly.

The surface uses a group chooser and explicit message/reply inspector, with search / DND toggle / duration / refresh controls. Alt+S copies a screenshot of the current view to the clipboard through `clip-daemon`. It provides **Active / History**, wrapped actions, expandable bodies, inline replies and 15-minute snooze. **Dismiss all active** and group dismissal retain history; the daemon's bulk dismissal also includes snoozed records. There is no history-deletion control.

When entered from Activity, Back or `Escape` restores Activity's calendar/detail state. Direct entry closes back to the desktop. The close button always closes. `Ctrl+Tab` switches Active/History; `F5` refreshes notifications. With the list focused, Up/Down selects a group and Right/Left expands/collapses it. Search and replies have no printable single-key shortcuts.

Panels follow the [mandatory interaction contract](chooser-keyboard-workflow.md): Tab traverses editable fields, Enter/Tab saves, and Escape discards the current field edit. Todo entry uses Alt+A to add; Alt+D deletes the currently browsed todo. Alt+R sends the current reply; Alt+J opens other content actions. Saving a reply field retains its draft, rather than sending it.

Saved reply drafts are shared with toasts and retained in memory when views close, filters change or records update. Uncommitted panel-field edits are discarded on leaving. Only an acknowledged successful reply clears the matching draft; failures retain it for retry. Drafts are not persisted across Shelllist restarts.

## Ownership

Shelllist owns only:

- Hyprland/Quickshell layer-shell surfaces and monitor placement;
- month, agenda, todo, notification, and world-clock rendering;
- selected date, viewed month, focus, scroll, expanded groups, and open tab;
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

In native notification mode, `bar-daemon` owns `org.freedesktop.Notifications` and publishes a bounded, recoverable snapshot containing only unsnoozed active records. The Active tab uses that snapshot directly, independently of history pagination. History is loaded while Notifications is open and requested in pages of 50; its count is explicitly labelled **loaded**. Refresh merges/deduplicates by history ID and catches up across missing pages rather than discarding older loaded records. Search filters records before grouping. Group models are reconciled by key, with retained expansion and scroll anchors. Loading, unavailable, failed, empty and no-match states are distinct.

Both active and historical records use the same frontend grouping policy:

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
| `activity/NotificationState.qml` | Shared active/history data, expansion and reply drafts |
| `activity/NotificationBackend.qml` | Notification requests, acknowledgements and stream adapter |
| `activity/NotificationController.qml` | Callout navigation, search and keyed group model |
| `activity/NotificationContent.qml` | Standalone notification surface and return navigation |
| `activity/ActivityContent.qml` | Anchored calendar/agenda/todo composition |
| `activity/ActivityGlancePane.qml` | Calendar and schedule summary |
| `activity/TimeWeatherContent.qml` | City list and two-tab Time & Weather composition |
| `activity/TimeWeatherTimePane.qml` | Local time, sun position, moon, and timezone detail |
| `activity/ActivityWeatherPane.qml` | Reusable local weather and forecast detail |
| `activity/ActivitySchedulePane.qml` | Calendar, selected-day agenda, and todo detail |
| `activity/NotificationContent.qml` | Shared group chooser, active/history filtering, DND, pagination and explicit message inspector |
| `activity/NotificationHistoryGroup.qml` | Expandable active and historical groups |
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
