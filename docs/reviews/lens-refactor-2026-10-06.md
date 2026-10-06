# Focused QML Quality Lens refactor — 2026-10-06

## Scope and evidence

Baseline: Shelllist `8b2810dd062bc4d947d6b692b173090a592f4942`.
Local QML Quality Lens: `../qmlqualitylens`, revision
`6868f2f113ef14b53deae673baf0ac654d17e869` (reported version 0.5.0).
Node 24.16.0; Qt 6.11.1. No analyzer configuration, thresholds, suppressions,
generated sources or dependency locks were changed.

This is a small maintenance pass, not a claim that the remaining hotspots have
been eliminated. Lens is advisory; native behavior and domain guards take priority.

Local evidence is in `target/lens-refactor-current/`: frozen `baseline-tree`,
`before/after-summary.json`, `before/after-records.json`, complete clone
inventories, and `before-tools/` / `after-tools/`. Static snapshots use the same
`snapshot.mjs` against both trees. Production excludes `tests/` and `dev/`.
Clone enumeration uses identical expanded limits (200,000 keys, 1,000 windows
per key, 10,000 groups); both inventories report no omitted windows or groups.
These numbers are not the capped clone counts in the stock full-tool report.

## Changes

- **Shared drawing:** `Ui.ChartDrawing.segment` supports an explicit null fill
  for line-only paths. Application resources and hourly weather now reuse it;
  battery history retains its existing consumer. Resource steps still own their
  interval vertices, and domains still own gaps, availability, axes and totals.
  Shared areas fill before stroking, retaining the outline above the fill.
- **Shared row containers:** window and desktop-action groups reuse the existing
  `DetailColumnCard`, with zero padding/spacing and their original surface tone.
  Removed the redundant local column/implicit-height wiring and the unused
  `actionHeight` pass-through into `ApplicationPage`/`ApplicationInstanceList`.
  Stable command IDs, enabled guards and passive field traversal remain intact.
- **Simpler control flow:** native-focus handling checks the save/discard
  reentrancy guard once and separates loss of focus from entry into an editor.
  Notification completion handles the no-snapshot case before snapshot routing;
  generations, queued-event flushing and acknowledgements are unchanged.
  Bluetooth operation lookup uses `find`, retaining first-match and empty-key
  behavior.
- **Dead code:** removed the unreferenced `ChartValueRail` component/export,
  unused VPN `activeFor`/`isActive` helpers, four unused QML IDs, and a duplicate
  battery focus ring. Repository reference searches supplemented Lens's
  reachability hints; exported platform-enum test stubs were not treated as dead.
- **Typing:** four actual string sequences now use `list<string>`: clipboard
  replacement IDs, timezone region IDs, display focus keys and Wi-Fi spinner
  frames. JSON payloads, Canvas contexts and intentional circular/dynamic
  boundaries retain their appropriate `var` types.

No new generic dispatcher, component family, panel-local keyboard behavior or
backend write path was introduced. Most normalized clones are generated protocol
declarations, imports or unrelated option tables; those were not consolidated.

## Measurements

| Metric | Production before → after | All analyzed sources before → after |
| --- | ---: | ---: |
| Source lines | 38,589 → 38,507 | 47,339 → 47,304 |
| Physical lines | 43,083 → 42,995 | 52,102 → 52,062 |
| Components | 297 → 296 | 352 → 351 |
| Cyclomatic complexity | 7,579 → 7,573 | 8,289 → 8,289 |
| Cognitive complexity | 5,143 → 5,131 | 5,447 → 5,437 |
| Function effort | 37,929 → 37,875 | 44,262 → 44,252 |
| Component effort | 42,647 → 42,524 | 52,629 → 52,560 |
| Mean leverage | 36.5488 → 36.8243 | 32.3864 → 32.6068 |
| Mean locality | 75.4815 → 75.4527 | 76.6023 → 76.5641 |
| Clone groups | 114 → 113 | 152 → 152 |
| Clone-covered lines | 1,588 → 1,580 | 2,175 → 2,162 |
| `property var` occurrences | 452 → 448 | 490 → 486 |

Tracked code across QML/JS/TS/scripts/Nix/Rust falls **58,874 → 58,835** lines,
including added regression coverage. The broad heuristic score remains **83**.
`ignoreUnknownSignals: true` stays at zero; lint-disable occurrences stay at 15.
`property var` is a proxy, not proof that every remaining occurrence is an escape hatch.

Locality is a qualified result, not an aggregate win: `ApplicationDesktopActions`
improves **75 → 81**, `ApplicationDetails` **77 → 78**, and `ApplicationPage`
**69 → 70**. Removing the unused locality-92 component lowers the production mean
slightly despite those improvements. Added pixel-test wiring also lowers the
resource test component's locality. All-source cyclomatic complexity is unchanged
because regression coverage offsets production reductions.

The shared native-focus handler improves cyclomatic **14 → 12**, cognitive
**18 → 12**, effort **70 → 59**. Notification `finish` improves cognitive
**20 → 18** and effort **90 → 86**, with cyclomatic unchanged at 17.
`ChartDrawing` has three production consumers instead of one; Lens counts four
including its new direct test, so its reported leverage rises **15 → 60**.
Cleanup findings fall **6 → 1**; the remaining finding is the intentionally
retained Quickshell `Status` enum test boundary.

## Validation and limitations

Passed:

- `tests/run-qml-tests.sh`: **335 passed, 0 failed, 1 skipped**. New tests exercise
  actual Canvas line/area/gap/dot pixels and Bluetooth first-match/empty guards;
  the native-focus test now moves directly between editors before leaving details.
- Targeted `QT_SCALE_FACTOR=1.25` chart, application-row and native-focus tests:
  **11 passed**, including setup/cleanup. Canvas pixel probes account for DPR.
- Strict `tests/run-qmllint.sh`; Lens's lint invocation also reports zero findings.
- `tests/run-runtime-smoke.sh`: both real Quickshell fixtures load offscreen.
- Generated TypeScript check, daemon-boundary check, resource arithmetic and
  availability checks, application-history recovery and Bluetooth lifecycle checks.
- `nix build .#shelllistConfig --no-link` and `git diff --check`.
  Nix's incidental lock update was reverted; no dependency update is part of this work.

Qt runs used
`FONTCONFIG_FILE=/nix/store/2yaykpml9f572ij53l2107nkxg6ln7v8-fonts.conf`.
Final direct logs are `/tmp/lens-refactor-qt-final.txt`,
`/tmp/lens-refactor-fractional.txt`, `/tmp/lens-refactor-lint-final.txt`,
`/tmp/lens-refactor-smoke.txt` and `/tmp/lens-refactor-nix.txt`.

Both full-tool runs used:

```sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all \
  --config qmlqualitylens.config.json
```

**The full Lens contract remains incomplete, not green.** Its profiler wrapper
hits the tool timeout in both baseline and final runs, despite the final JUnit
artifact recording 335 executions with zero failures. Coverage/performance
observations are consequently unavailable. The final contract also reports an
incomplete formatter execution and unresolved semantic-rule targets. No timeout,
rule or suppression was relaxed to hide these limitations. The independent native
suite above completed successfully; no performance improvement is claimed.

The complete daemon contract matrix, full package build, live compositor/hardware
and screen-reader acceptance were not run. Existing transaction, retry and safety
guards remain in place. See the updated [interaction contract](../chooser-keyboard-workflow.md).
