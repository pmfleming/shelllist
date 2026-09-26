# QML maintenance review: baseline checkpoint

Application baseline: `ed08701`. Local QML Quality Lens: `80cb7a9` (0.5.0).
The initial checkpoint recorded review evidence only. Implementation slices and
validation are recorded below; the table retains the unchanged baseline.

## Comparable baseline

Production excludes `tests/` but includes generated sources unchanged. Complexity,
effort, leverage and locality are Lens heuristics, not measured development time.

| Production metric | Baseline |
| --- | ---: |
| Function cyclomatic complexity, sum | 6,595 |
| Function cognitive complexity, sum | 5,146 |
| Function effort, sum | 31,030 |
| Component effort, sum | 40,512 |
| Mean component locality | 75.71 |
| Mean component leverage | 52.76 |
| Normalized-line clone groups | 155 |
| Distinct clone-covered lines | 2,233 |
| Source lines | 31,442 |
| Physical lines | 34,440 |
| `property var` declarations | 420 |
| `ignoreUnknownSignals: true` declarations | 4 |
| `qmllint disable` directives | 19 |

Including analyzed tests: 37,001 source lines and 40,274 physical lines.
Tracked source physical lines (`qml/js/ts/mjs/py/sh/nix/rs`, including tests outside
Lens roots): 45,910. Markdown is excluded. The rounded Lens score is 86.

Clone counts use expanded budgets of 200,000 keys, 1,000 windows per key and
10,000 groups: no omitted windows or groups. Default Lens clone output is partial;
its capped counts must not be substituted for this complete normalized-line scan.
Structural clones are a separate heuristic. Dynamic properties and suppression
counts are review inventories, not counts of confirmed defects.

## Findings and proposed slices

1. **Cleanup and explicit contracts.** Lens reports four unused IDs: `closeButton`
   in `NotificationContent`, `expandButton` in `NotificationHistoryRow`,
   `numberField` in `DisplayFocusSetting`, and the first factory's `scene` in
   `tst_focus_feedback`. The second factory's `scene` is referenced and must stay.
   The shell's `Connections` target is already a typed `ChooserController` whose
   contract declares both handled signals; `ignoreUnknownSignals` is unnecessary
   there. Native lint also identifies three unused `QtTest` imports in tests.
2. **Unused exports require an explicit decision.** Workspace QML searches find
   no consumers of `ChartFrame`, `ChooserWindowHost` or `DisclosureSection`.
   They remain exported through `qmldir`, so Lens does not report them as unused
   components. Confirm the intended in-repository API boundary before removing
   these exports; lack of observed use is not proof about external consumers.
3. **Display validation.** `DisplayModel.validate` is the largest authored
   function hotspot: cyclomatic 28, cognitive 57, effort 178. Separate cohesive
   validation responsibilities without duplicating policy or changing error
   precedence. Preserve mode matching, mirror-source constraints, numeric
   boundaries, and the independent-output safety check. Existing Node and QML
   tests are the starting point; add boundary/precedence and differential coverage.
4. **Shared presentation.** Notification history and toast cards repeat
   reply/snooze/dismiss controls. Consider sharing that specific control group,
   keeping expiry, swipe removal, grouping and domain actions with their owners.
   Details-pane wiring is another clone candidate, but a thin forwarding wrapper
   or a configurable catch-all is not automatically an improvement.
5. **Legitimate dynamic boundaries.** SearchService's lazy process adapter and
   PopupWindowHost's Quickshell window/screen access need individual investigation.
   Do not remove suppressions blindly or introduce eager loading merely to improve
   static scores. Keep generated protocol sources and daemon ownership intact.

Measure production totals including extracted helpers, not just smaller callers.
Report test growth separately and count it in repository-wide LOC. Do not relax
thresholds, exclude difficult files or add suppressions to claim improvement.

## Implementation ledger

- Cleanup: removed the four verified unused IDs, three unused test imports and
  the shell's unnecessary unknown-signal suppression. Removed the three unused
  UI exports after reviewing workspace consumers and dynamic edges: this module
  is an in-repository implementation, not a supported external toolkit API.
  Strict lint, all 201 Qt passes (including hooks), and offscreen shared-UI smoke
  pass. No runtime behavior, protocol or daemon source was changed.
- Notification quick actions: shared reply/snooze/dismiss rendering and focus
  containment between history and toast cards. Callers retain visibility,
  grouping, reply state and immediate-versus-animated dismissal policy. The
  shared component has no controller/daemon dependency. Strict lint, 202 Qt
  passes and offscreen smoke pass; added tests exercise keyboard/pointer signals,
  disabled activation, focus transfer and hidden-reply layout.
- Display validation: split per-output field checks from layout identity/order
  checks and shared the independent-output predicate with mirror/extend helpers.
  `validate` drops from cyclomatic/cognitive/effort 28/57/178 to 9/13/51;
  the extracted field validator is 19/18/79. Production function effort falls
  even including helpers. Node boundary/error-precedence tests, 80,000 seeded
  before/after comparisons, strict lint and 202 Qt passes succeed. No daemon
  validation, preview/revert or acknowledgement policy was changed.

## Baseline execution evidence

Using the supported local-build development environment:

```sh
npm --prefix ../qmlqualitylens run build
tests/run-performance-benchmarks.sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all \
  --config qmlqualitylens.config.json
```

- Qt test execution: 201 passes including lifecycle hooks, zero failures.
- Native Qt 6.11.1 lint: complete coverage of 362 discovered files, zero errors
  or warnings; three informational unused-import diagnostics remain.
- Offscreen shared-UI runtime smoke: pass, no runtime-warning findings.
- Lens contract: `warn`, no verified or semantic failures. Review findings,
  a skipped check and benchmark noise remain visible. This is not a clean audit
  or a claim that every optional check ran.
- No live compositor review, deployment or service restart was performed.

Local raw evidence is ignored rather than committed: Shelllist
`target/lens-maintenance/before-tools/` and its archived `baseline/`; adjacent Lens
`target/shelllist-maintenance/before*.json` and `snapshot.mjs`. The snapshot script
uses the same project configuration with external execution disabled for static
metrics and expanded clone budgets. Use the same analyzer and scope for the
post-refactor comparison; execution evidence is collected separately.
