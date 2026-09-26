# QML maintenance review and refactoring results

Application baseline: `ed08701`; final source checkpoint: `ea29dc6`.
Both snapshots use local QML Quality Lens `80cb7a9` (0.5.0), unchanged
configuration, discovery scope and thresholds. The initial review was committed
separately in `aceff04`; four tested implementation slices followed.

## Comparable results

Production excludes `tests/` but includes generated sources unchanged. Complexity,
effort, leverage and locality are Lens heuristics, not measured development time.

| Production metric | Before | After |
| --- | ---: | ---: |
| Function cyclomatic complexity, sum | 6,595 | 6,579 |
| Function cognitive complexity, sum | 5,146 | 5,099 |
| Function effort, sum | 31,030 | 30,890 |
| Component effort, sum | 40,512 | 40,372 |
| Mean component locality | 75.71 | 75.70 |
| Mean component leverage | 52.76 | 53.24 |
| Normalized-line clone groups | 155 | 155 |
| Distinct clone-covered lines | 2,233 | 2,232 |
| Source lines | 31,442 | 31,321 |
| Physical lines | 34,440 | 34,312 |
| `property var` declarations | 420 | 423 |
| `ignoreUnknownSignals: true` declarations | 4 | 3 |
| `qmllint disable` directives | 19 | 19 |
| Unused ID cleanup findings | 4 | 0 |

Including analyzed tests: source lines 37,001 → 36,961; physical lines
40,274 → 40,232. Tracked source physical lines (`qml/js/ts/mjs/py/sh/nix/rs`,
including tests outside Lens roots): 45,910 → 45,893. Markdown is excluded;
total repository text grows because this review is added. The rounded score
remains 86.

Leverage improves, but aggregate locality is essentially flat, not an overall
improvement. NotificationController locality rises 80 → 81 and
NotificationHistoryGroup 59 → 61. The new quick-action component scores 84 for
locality / 85 for leverage; SerializedListModel scores 100 / 90 and raises
KeyedListModel leverage 71 → 86. Removing unused, high-locality leaf components
also changes the population mean.

There is no material improvement in normalized clone counts: these algorithms
and control groups were semantically duplicated, not necessarily identical
normalized windows. Including tests, clone-covered lines rise 2,797 → 2,807.
Three new `var` declarations carry actual serialized model data, not unchecked
QObject access. One unnecessary signal escape hatch is removed; no lint
suppression or cast was introduced. Remaining dynamic framework boundaries
are deliberately retained rather than weakened for a score.

Clone counts use expanded budgets of 200,000 keys, 1,000 windows per key and
10,000 groups: no omitted windows or groups. Default Lens clone output is partial;
its capped counts must not be substituted for this complete normalized-line scan.
Structural clones are a separate heuristic. Dynamic properties and suppression
counts are review inventories, not counts of confirmed defects.

## Initial findings and scope decisions

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

- Cleanup (`396106d`): removed the four verified unused IDs, three unused test imports and
  the shell's unnecessary unknown-signal suppression. Removed the three unused
  UI exports after reviewing workspace consumers and dynamic edges: this module
  is an in-repository implementation, not a supported external toolkit API.
  Strict lint, all 201 Qt passes (including hooks), and offscreen shared-UI smoke
  pass. No runtime behavior, protocol or daemon source was changed.
- Notification quick actions (`9fa08ac`): shared reply/snooze/dismiss rendering and focus
  containment between history and toast cards. Callers retain visibility,
  grouping, reply state and immediate-versus-animated dismissal policy. The
  shared component has no controller/daemon dependency. Strict lint, 202 Qt
  passes and offscreen smoke pass; added tests exercise keyboard/pointer signals,
  disabled activation, focus transfer and hidden-reply layout.
- Display validation (`02c63b5`): split per-output field checks from layout identity/order
  checks and shared the independent-output predicate with mirror/extend helpers.
  `validate` drops from cyclomatic/cognitive/effort 28/57/178 to 9/13/51;
  the extracted field validator is 19/18/79. Production function effort falls
  even including helpers. Node boundary/error-precedence tests, 80,000 seeded
  before/after comparisons, strict lint and 202 Qt passes succeed. No daemon
  validation, preview/revert or acknowledgement policy was changed.
- Notification models (`ea29dc6`): replaced the second hand-written reconciliation algorithm
  with a small `SerializedListModel` specialization of `Core.KeyedListModel`.
  Serialization stays beside the model to preserve nested action arrays; this
  specialization always reconciles synchronously without resets/chunks so live
  reply delegates survive large updates. Group scroll capture/update signals
  retain their original order. Strict lint, 203 Qt passes, Node notification
  checks and offscreen smoke pass, including a 205-record burst while editing
  a reply and equal-payload/no-rewrite checks.

## Final validation and remaining work

- Strict Qt 6.11.1 lint covers all 361 discovered files with zero diagnostics.
- Qt execution: **203 passes**, including lifecycle hooks, zero failures/skips.
- Offscreen shared-UI smoke and deterministic performance checks pass.
- The full `local-build.py check . --keep-going --print-build-logs` gate reports
  **all checks passed**, including current sibling packages, protocol contracts,
  packaging, daemon boundaries and QML tests. Sibling sources and locks were not
  modified by this refactor.
- Lens `measure all` completes; contract remains `warn`, with zero verified or
  semantic failures. Formatting, partial default clone coverage, incomplete
  coverage/review evidence and the skipped optional check remain visible.
- No live compositor, hardware, deployment or service restart was tested.

This is a bounded maintenance pass, not completion of every quality goal.
Controller coordination and presentation binding pressure remain hotspots.
Further clone work should target real shared behavior, not consolidate unrelated
option tables merely because normalized literals look alike. Future locality
work must preserve explicit ownership and avoid proliferating thin wrappers.

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
`target/lens-maintenance/{before-tools,after-tools}/` and its archived `baseline/`;
adjacent Lens `target/shelllist-maintenance/{before,after}*.json`, `snapshot.mjs`
and `display-differential.cjs`. The snapshot script uses the same project
configuration with external execution disabled for static metrics and expanded
clone budgets. Execution evidence is collected separately. The full gate log is
`/tmp/shelllist-maintenance-full-check.log`; focused validation logs are
`/tmp/shelllist-{cleanup,notification-controls,display-validation,serialized-model}-tests.log`.
