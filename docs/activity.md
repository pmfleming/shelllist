# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened from the top-bar Activity module, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- a time/weather callout that opens the separate Time & Weather city chooser;
- a month calendar and selected-day agenda;
- persistent todos and source-health reporting;
- newest-first notification previews with app identity and relative time, filling the available height;
- a DND on/off toggle, a shared 30 min / 60 min / ∞ duration cycling button, and a link to Notifications.

Agenda and Notifications share one top-bar icon, which always opens the agenda. **Super+Shift+N** opens Notifications directly (installed by the Home Manager module when Hyprland is enabled; configurable with `programs.shelllist.notificationsShortcut`, or see the README binding). Changing the duration while DND is off only selects the next duration; while on it restarts DND with that duration. ∞ enables DND without an expiry.

The Activity glyph in the panel header identifies the surface and acts as its screenshot control. Activating it captures the complete visible Activity panel through `clip-daemon` and copies the image into clipboard history.

Active notifications appear in up to three compact notification stacks per monitor. A stacked toast shows only its newest record and a count badge; its chevron opens that group in the separate Notifications callout. Activity previews also open their specific group in Active or History. `shelllist notifications open|toggle` and the `notifications` global shortcut open the pane directly.

The pane is a centered, responsive single-column surface with the standard screenshot / search / DND toggle / duration / refresh toolbar at the top. The bell captures the visible pane to clipboard history through `clip-daemon`. It provides **Active / History**, wrapped actions, expandable bodies, inline replies and 15-minute snooze. **Dismiss all active** and group dismissal retain history; the daemon's bulk dismissal also includes snoozed records. There is no history-deletion control.

When entered from Activity, Back or `Escape` restores Activity's calendar/detail state. Direct entry closes back to the desktop. The close button always closes. `Ctrl+Tab` switches Active/History; `F5` refreshes notifications. With the list focused, Up/Down selects a group and Right/Left expands/collapses it. Search and replies have no printable single-key shortcuts.

Reply drafts are shared with toasts and retained in memory when views close, filters change or records update. Only an acknowledged successful reply clears the matching draft; failures retain it for retry. Drafts are not persisted across Shelllist restarts.

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

The closed layout is a right-edge glance panel constrained to roughly 25–33% of the focused screen. On Hyprland, its top, right and bottom edges are anchored to the current monitor's usable workspace bounds: live reserved space plus the effective workspace outer gaps. No bar height or gap is hardcoded. Placement uses logical screen coordinates, follows monitor/scale/workspace changes, and clamps the surface width to the available area. Geometry is refreshed on compositor events and once per second while open (to catch runtime configuration changes without events); no geometry polling runs while hidden. Centered callouts keep their usual ratio-based placement. It stacks time/weather, schedule/todo, and as many recent notification previews as fit. Previews merge the active snapshot with loaded history, deduplicate active/history overlap, and sort newest first, so notifications remain visible after expiry or dismissal. Time/weather and notifications open separate callouts without widening Activity. Only schedule expands a detail pane inward while preserving the glance rail. `1` opens Time & Weather, `2` expands schedule, and `3` opens Notifications. Within Activity, `Escape` returns to the glance panel before closing the surface.

Time & Weather follows the same list/detail interaction as Wi-Fi and Bluetooth. The list combines configured weather locations and world clocks by timezone, showing city, current weather, and local time. `Right` expands the selected city. The detail pane has **Time** and **Weather** tabs; Time renders a world map that highlights every region sharing the selected current UTC offset and marks configured location coordinates, plus sun position, day length, and moon phase. Weather reuses the existing hourly, daily, and weather-metric presentation. The bar clock and timezone modules open this chooser directly.

Shelllist requests only a buffered range around the visible month. A compact `activity.changed` event schedules a debounced range refresh rather than carrying the full range in every event. Weather locations—including which location is home, labels, coordinates, and timezones—come entirely from `bar-daemon/activity.json`; no city is compiled into the UI. `bar-daemon` refreshes configured Open-Meteo locations concurrently at most every 15 minutes and retains each last successful forecast through transient failures.

In native notification mode, `bar-daemon` owns `org.freedesktop.Notifications` and publishes a bounded, recoverable snapshot containing only unsnoozed active records. The Active tab uses that snapshot directly, independently of history pagination. History is loaded while either Agenda or Notifications is open and requested in pages of 50; its count is explicitly labelled **loaded**. Refresh merges/deduplicates by history ID and catches up across missing pages rather than discarding older loaded records. Search filters records before grouping. Group models are reconciled by key, with retained expansion and scroll anchors. Loading, unavailable, failed, empty and no-match states are distinct.

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
| `activity/ActivityContent.qml` | Right-edge glance/detail composition |
| `activity/ActivityGlancePane.qml` | Compact time, schedule, and notification summaries |
| `activity/TimeWeatherContent.qml` | City list and two-tab Time & Weather composition |
| `activity/TimeWeatherTimePane.qml` | Local time, sun position, moon, and timezone detail |
| `activity/ActivityWeatherPane.qml` | Reusable local weather and forecast detail |
| `activity/ActivitySchedulePane.qml` | Calendar, selected-day agenda, and todo detail |
| `activity/ActivityNotificationsPane.qml` | Active/history list, search, DND and pagination controls |
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
