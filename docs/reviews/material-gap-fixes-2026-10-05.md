# Material gap fixes — 2026-10-05

Owner scope: implement findings **2–5** of the Material gap review, committing
one fix at a time. Finding 1 is explicitly **not** a requested change: keyboard
navigation must not enter the Power history chart for now. Keep it out of field
traversal and command discovery; do not add a keyboard inspection route. Existing
explicit pointer inspection is unaffected. This decision supersedes the review's
recommendation to add a chart-entry command.

## 2 — Destructive icon contrast

`DestructiveIconButton` now pairs the error fill with `Theme.dangerText` instead
of forcing white in both themes. The actual shared control is checked under
pointer hover, keyboard focus and keyboard press in light and dark mode, including
the composited focus tint. Each icon/fill pair must retain at least 3:1 contrast.

Validation: strict QML lint passed; `MaterialFeedback` — 2 behavioral cases /
4 Qt passes with hooks. Log: `/tmp/material-fix2-checks.log`.
No chart navigation, domain effects or destructive-action dispatch changed.

## 3 — Distinguishable browse focus

The immediate tonal tint now includes a compact opaque Primary pill with a
Surface keyline, rather than relying on 8% tint contrast. The keyline keeps the
cue distinguishable over selected and filled controls without outlining the
whole control. Horizontal sliders place it above their track. Editing keeps its
stronger tint/edge; focus feedback never animates or changes hit geometry.

Native rendered-pixel checks cover seven seeds, both themes and five underlying
fills (70 combinations), with decorative motion enabled. Marker/keyline pixels
must reach 3:1. The real field workflow verifies immediate browse/edit/discard
transitions. A Battery regression cycles Tab without entering the chart and
retains explicit pointer inspection, enforcing the owner's scope decision.

Validation: strict lint; MaterialFeedback 6, FieldInteraction 17, BatterySuspend
7 Qt passes including hooks. Packaged-font light/dark focus captures were
inspected; the separate capture fixture adds 5 passes. Logs:
`/tmp/material-fix3-tests.log`, `/tmp/material-fix3-additional.log`.

## Remaining

Findings 4 (tray assistive activation) and 5 (custom-card containment) follow in
separate commits. Live compositor, hardware input and screen-reader acceptance
remain separate from offscreen checks.
