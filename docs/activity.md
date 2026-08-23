# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened from the top-bar Activity module, clock, notification indicator, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- local time, optional Open-Meteo weather, and world clocks;
- a month calendar and selected-day agenda;
- persistent todos and source-health reporting;
- grouped, paginated notification history;
- notification actions, inline replies, dismissal, snooze, and clearing;
- indefinite DND and timed presets for 30 minutes, 1 hour, 2 hours, or 8 hours.

Active notifications appear in up to three expandable notification groups per monitor. A group can be cleared as one stack, while individual cards can be dismissed or snoozed for 15 minutes. Clear-all applies across all groups.

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

The closed layout is a right-edge glance panel constrained to roughly 25–33% of the focused screen. It starts directly below the 51 px top bar and extends to the bottom edge. It stacks time/weather, schedule/todo, and notification summaries. Selecting a card expands a detail pane inward while preserving the glance rail, following the same master/detail model as the Applications, Wi-Fi, and Bluetooth surfaces. Detail panes complement rather than duplicate the visible glance card: Weather starts with future trends and other locations, Schedule omits the month already visible in the rail, and Notifications keeps record previews exclusively in grouped history. `1`, `2`, and `3` open the three detail sections; `Escape` returns to the glance panel before closing the surface.

Shelllist requests only a buffered range around the visible month. A compact `activity.changed` event schedules a debounced range refresh rather than carrying the full range in every event. Weather locations—including which location is home, labels, coordinates, and timezones—come entirely from `bar-daemon/activity.json`; no city is compiled into the UI. `bar-daemon` refreshes configured Open-Meteo locations concurrently at most every 15 minutes and retains each last successful forecast through transient failures.

In native notification mode, `bar-daemon` owns `org.freedesktop.Notifications` and publishes a bounded, recoverable snapshot containing only unsnoozed active records. History is requested in pages of 50.

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
| `activity/ActivityBackend.qml` | The only Activity transport component |
| `activity/ActivityController.qml` | Ephemeral range, pagination, selection, and presentation state |
| `activity/ActivityContent.qml` | Right-edge glance/detail composition |
| `activity/ActivityGlancePane.qml` | Compact time, schedule, and notification summaries |
| `activity/ActivityWeatherPane.qml` | Local weather, forecast, and world-clock detail |
| `activity/ActivitySchedulePane.qml` | Calendar, selected-day agenda, and todo detail |
| `activity/ActivityNotificationsPane.qml` | Filtered notification history and DND controls |
| `activity/NotificationHistoryGroup.qml` | Expandable historical groups |
| `bar/NotificationToastStack.qml` | Monitor-local active groups |
| `qml/Shelllist/Ui/NotificationPresentation.js` | Shared grouping, routing, and DND labels |
| `qml/Shelllist/Ui/RemovalAnimation.qml` | Shared transient dismissal animation |

`ActivityContent.qml` contains no filesystem, provider, subprocess, persistence, or notification-policy integration.

## Validation

The checked `bar-api` fixture validates `bar/BarApi.js` and `activity/ActivityApi.js` against the backend registry. Focused checks are:

```sh
node tests/check-notification-presentation.js qml/Shelllist/Ui/NotificationPresentation.js
node tests/check-flow-policies.js activity/ActivityFlow.js \
  battery/BatteryFlow.js clipboard/ClipboardFlow.js
tests/check-bar-api-contract.sh ../bar-daemon/target/debug/bar-daemon \
  contracts/bar-api-ui-contract.fixture.json bar/BarApi.js \
  activity/ActivityApi.js qml/Shelllist/Battery/BatteryApi.js
nix flake check
```
