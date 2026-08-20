# Activity UI plan

Shelllist is the presentation client for the `bar-daemon` Activity module. It does not parse iCalendar, contact providers, schedule reminders, persist todos, own notification IDs, or decide DND/fullscreen policy.

## Ownership

Shelllist owns only:

- Hyprland/Quickshell layer-shell surfaces and monitor placement;
- month, agenda, todo, notification, and world-clock rendering;
- selected date, viewed month, focus, scroll, and open tab;
- locale-aware labels and time formatting;
- animations and input;
- translating user intent into bar-api calls.

`bar-daemon` owns all durable data, source health, ordering, range bounds, mutations, retries, and policy. Shelllist must be restartable without losing Activity state.

## Surface

`activity` is a lazy Shelllist surface opened by:

- the top-bar Activity module;
- the clock;
- the notification indicator;
- `shelllist activity open|toggle`;
- the `activity` global shortcut.

The initial wide layout has a month/notification-summary column, selected-day agenda, and todo/world-clock column. The frontend asks only for the buffered range around the visible month. Changing compact `activity.changed` state schedules a debounced range refresh.

During the native notification migration, the surface uses the existing SwayNC summary and opens SwayNC history. Once `bar-daemon` owns `org.freedesktop.Notifications`, the same surface will render daemon-provided history and toast streams without changing its ownership boundary.

## Frontend contract

`activity/ActivityApi.js` declares all Activity methods and streams. `ActivityBackend.qml` is the only transport component. `ActivityController.qml` holds ephemeral presentation state. `ActivityContent.qml` renders that state and contains no filesystem, provider, subprocess, or persistence integration.

The checked `bar-api` fixture validates both `bar/BarApi.js` and `activity/ActivityApi.js` against the backend registry.
