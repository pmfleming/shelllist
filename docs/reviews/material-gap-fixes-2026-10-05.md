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

## 4 — Tray assistive activation

Inline tray items now route accessible press through the same primary dispatch
as pointer clicks. Menu-only items open their menu without falling through to
activation; disabled, hidden and removed items cannot dispatch. The bar remains
outside keyboard Tab traversal. The native menu host defaults to the same
`QsWindow.window`; tests can supply a recording host.

The platform fixture now models the real status enum and records menu hosts,
closing the review probe's missing-enum warning instead of suppressing it.
Regression coverage includes ordinary activation, menu-only/missing-menu cases,
disabled/hidden/removed guards and pointer/assistive parity. Existing dedicated
Tray chooser/native-menu lifecycle tests still pass.

Validation: strict lint; MaterialBar 6 and SystemChoosers 7 Qt passes including
hooks, with no reported warnings. Log: `/tmp/material-fix4-checks.log`.

## 5 — Opaque custom-card containment

Battery history, Applications resource lanes and Applications resource metadata
now use the same opaque Surface Container Low fill as shared detail cards.
Battery history explicitly has no outer border. Chart series/gradients, metadata
badges, layout, range controls and telemetry remain unchanged.

Native tests check all three real components across a live light/dark change:
opaque semantic fill, no outer border, rendered background pixels and unchanged
geometry. Packaged-font before/after card captures and the actual Battery panel
were inspected. Historical before samples are fixture-only color overrides, not
production settings.

## Final validation

- Strict QML lint: passed.
- Full native Qt suite: **222 passes including hooks; 0 failed, 0 skipped**.
- Material color check: **150 seed/mode combinations passed**.
- Both native offscreen runtime smoke configurations: loaded successfully.
- Separate visual capture fixture: **5 passes including hooks**; images in
  `target/material-gap-fixes/`.
- Logs: `/tmp/material-fixes-final-checks.log`,
  `/tmp/material-fixes-final-captures.log`.

Failure-path tests intentionally log backend errors. The runtime smoke retains
Qt offscreen's unsupported-window-mask warning; no warning suppression was added.
The full sibling-aware Nix gate was not run. No services were deployed/restarted;
live compositor, hardware input, screen-reader and final visual acceptance remain
separate. Pre-existing unrelated working-tree changes were not included in these
commits.
