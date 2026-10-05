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

## Remaining

Findings 3 (browse focus), 4 (tray assistive activation) and 5 (custom-card
containment) follow in separate commits. Live compositor, hardware input and
screen-reader acceptance remain separate from offscreen checks.
