# Material surface follow-up

Implementation of the [2026-09-29 audit](material-surface-audit-2026-09-29.md), in separate commits. Original audit observations describe its recorded snapshot, not the subsequent implementation.

## Notifications

- Browse/native focus immediately reveals quick actions in the inspector and toasts; hover cannot move selection or dispatch an action.
- Quick actions and group disclosure targets are 32px rather than 26px, with matching header allocation.
- The inspector's default action is keyboard/accessibility reachable; toasts expose their explicit activation to assistive technology without changing swipe behavior.
- Real inspector regression covers non-native browse focus, immediate visibility and no snooze/dismiss replay.
- Strict lint and native suite: 289 passes. Evidence: `/tmp/material-notifications-{lint,tests}.log`.

## Battery / Power

- Immediate lock/sleep/Keep awake actions lead the Power tab. Secondary threshold automation/hardware tuning is explicitly disclosed and opens automatically for errors or paused/blocked automation.
- Profiles use the shared single-choice editor: Enter focuses without changing power; native arrows dispatch a proposal, and the selected overview mode remains acknowledged.
- Charge history leads Overview; health/cycle summary precedes disclosed hardware details. Charging maintenance automatically stays visible during calibration/inhibition/errors.
- Lid/timer guidance is contextual, idle implementation prose is removed, and the critical-protection warning wraps without elision. Active countdowns, errors, retries and cancellation remain visible.
- Shared `DisclosureSection` only changes presentation, keeps children/drafts alive, and forces attention content open without dispatching effects.
- Regression coverage includes profile browse/edit/acknowledgement, primary action ordering and secondary error disclosure.

Live compositor, screen-reader, IME, touch and large-text acceptance remain separate. No services are restarted or deployed by this work.
