# Activity and notifications

Shelllist is the presentation client for the `bar-daemon` Activity domain. It does not parse iCalendar sources, schedule reminders, persist todos, own notification IDs, or decide notification expiry and DND policy.

## User behavior

The Activity surface is opened from the top-bar Activity module, clock, notification indicator, `shelllist activity open|toggle`, or the `activity` global shortcut. It combines:

- a month calendar and selected-day agenda;
- persistent todos and source-health reporting;
- world clocks;
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

The wide layout has a month/notification-summary column, selected-day agenda, and todo/world-clock column. Shelllist requests only a buffered range around the visible month. A compact `activity.changed` event schedules a debounced range refresh rather than carrying the full range in every event.

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
| `activity/ActivityContent.qml` | Surface composition |
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
