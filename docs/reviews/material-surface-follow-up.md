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

## Shared dialogs

- Reproduced long-content overflow with a 400×240 dialog fixture. The shared frame now scrolls its full, unelided title/instructions/body and reveals focused fields/actions rather than clipping them.
- Added explicit dialog role, accessible title and description. Conventional forward/reverse Tab wraps actual visible/enabled dialog controls, including sensitive native inputs omitted by Qt's default focus chain; native popup/Escape boundaries remain unchanged.
- Regression checks reachability in both directions, retained input text and accessible naming. Strict lint and the 292-pass native suite pass.

## Wi-Fi

- Profile settings now lead the ordinary detail body; connection/network diagnostics are explicitly disclosed. Connection/sign-in status remains in the header.
- Security/band/address/discovery/password controls precede device identifiers and DHCP metadata. Diagnostics never fetch secrets, save settings or reset live drafts/reveal state.
- Enterprise prompts, IP validation, acknowledgement and partial-save recovery are unchanged. Strict lint and 293 native passes, including the new disclosure/draft regression.

## Audio

- Added an in-content confirmed output-volume value and ±5% actions; mute and full-mixer access remain available. No absolute slider setter or device inventory is invented.
- Regression verifies delta routing, busy guards and acknowledged—not optimistic—volume. Strict lint and all 9 SystemChoosers Qt passes succeeded.

## Media

- Now-playing title/artist/album and transport lead the body; preferences are a retained secondary section. Play/Pause label and glyph follow actual player state, with a prominent transport action.
- Automatic mode has a concise choice plus contextual behavior; pin/automatic selection remains daemon-owned and acknowledged. Every transport still targets the explicit selected player and revalidates capabilities.
- Strict lint and 10 SystemChoosers Qt passes, including state/icon acknowledgement regression. The initially attempted `accent` action tone was rejected by the existing contract and corrected to supported `active`; the contract was not relaxed.

## Tray

- Supplied application icons now render in results and inspector identity, with the existing glyph as fallback. Primary activation/menu paths are labelled in the body; secondary/scroll actions are disclosed.
- Duplicate identities still disable every vendor action; native menu invocation/generation/focus guards are unchanged. No vendor menu content is restyled or serialized.
- Strict lint and 11 SystemChoosers Qt passes, including actual supplied-image loading, menu-only capability and native-menu cleanup. Added the real platform `icon` property to the test boundary mock.

Live compositor, screen-reader, IME, touch and large-text acceptance remain separate. No services are restarted or deployed by this work.
