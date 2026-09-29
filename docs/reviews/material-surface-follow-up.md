# Material surface follow-up

Implementation of the [2026-09-29 audit](material-surface-audit-2026-09-29.md), in separate commits. Original audit observations describe its recorded snapshot, not the subsequent implementation.

## Notifications

- Browse/native focus immediately reveals quick actions in the inspector and toasts; hover cannot move selection or dispatch an action.
- Quick actions and group disclosure targets are 32px rather than 26px, with matching header allocation.
- The inspector's default action is keyboard/accessibility reachable; toasts expose their explicit activation to assistive technology without changing swipe behavior.
- Real inspector regression covers non-native browse focus, immediate visibility and no snooze/dismiss replay.
- Strict lint and native suite: 289 passes. Evidence: `/tmp/material-notifications-{lint,tests}.log`.

Live compositor, screen-reader, IME, touch and large-text acceptance remain separate. No services are restarted or deployed by this work.
