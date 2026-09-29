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

## Displays

- Common global focus settings now lead a clearly named All monitors page; the 15 boolean settings use wrapping switch rows. Advanced groups, per-setting explanations/raw keys and restore semantics are explicitly disclosed.
- Focus changes retain acknowledgement, capability, layout-trial/disconnect and numeric-validation guards. The Focus page no longer displays selected-monitor actions or layout-draft instructions.
- Layout settings begin with a compact arrangement map. Precise positioning remains available without dragging; mirror constraints stay explicit when relevant.
- Preview and Identify have different symbols; Keep/Revert and timed rollback are unchanged. Docking retains its separately acknowledged immediate policy.
- Native suite: 291 passes; fresh packaged-font offscreen captures are in `target/material-surface-follow-up-captures/`. In the same healthy fixture, default Power content is 631px (previously 1153px); default Display Focus is 338px (previously 3536px). These reductions use disclosure, not removal of capabilities or smaller text.

Live compositor, screen-reader, IME, touch and large-text acceptance remain separate. No services are restarted or deployed by this work.
