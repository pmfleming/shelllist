# QML maintenance review — baseline `fba5e8a`

Measured with the clean local `../qmlqualitylens` checkout at `6868f2f`
(version 0.5.0). Baseline is an archive of clean Shelllist `fba5e8a`; no incoming
edits, analysis exclusions, suppressions or test removals are involved.
Local evidence and the comparison script are in `target/quality-refactor/`.

## Findings and changes

1. **Reply ownership defect:** an empty location reply ID could match the idle
   search slot after a completed search and overwrite a pending mutation's
   diagnostic. `TimeWeatherLocations.finish` now rejects empty IDs before routing.
   The new native regression fails on the archived baseline and passes after the
   fix. Unowned/duplicate replies and invalid city acknowledgements are covered.
2. **Mixed completion responsibilities:** search, control-status recovery, city
   validation/publication and mutation completion now have separate local methods.
   Request IDs, captured revisions/places, modal generations, selection, explicit
   recovery and no-replay guards remain with the same owner. Peak cyclomatic /
   cognitive complexity in this file falls **57/100 → 17/18**; function effort
   sum falls **649 → 583**. Its cyclomatic sum rises **133 → 136** because
   extraction adds function baselines; this is not removal of necessary guards.
3. **Repeated passive containers:** Activity Agenda and Todos reuse `DetailCard`
   padding/surface composition; Agenda also uses its passive heading. No new
   setting wrapper, key model, focus stop or numeric style override. Existing
   Activity native day-command/todo tests exercise the migrated consumer.
4. **Unnecessary indirection/dynamic boundary:** Bluetooth's four single-use
   setting factories become one local descriptor construction, retaining
   `Core.Model.settingToggle`, capability gates, visibility and disabled reasons.
   `BarStateRecovery.backend` is explicitly `BarDaemonBackend`, not `var`.
5. **Confirmed-unused code:** remove notification alias/count projections,
   clipboard cache-byte telemetry (not the cache budget), display selected-number
   projection, hotspot reason projection, unused network-health observation copies
   and their derived message, an unused opacity token, `hasPendingOtherThan`, and
   the stale SystemEntries test import. Health logging/status/deduplication and
   authoritative domain state remain intact. Reference review included generated
   change-handler names, tests and dynamic consumers; no component export was
   removed on reachability evidence alone.

## Matched static measurements

Both snapshots retain the configured roots and dynamic edges. **Production here
includes generated sources**, excluding only `tests/` and `dev/`; this differs
from some older reviews and their totals must not be compared directly.

| Metric | Production before → after | Full configured scope before → after |
| --- | ---: | ---: |
| Source lines | 41,616 → 41,584 | 52,402 → 52,405 |
| Physical lines | 46,357 → 46,322 | 57,456 → 57,456 |
| Function cyclomatic sum | 8,605 → 8,603 | 9,781 → 9,784 |
| Function cognitive sum | 6,118 → 6,078 | 6,708 → 6,670 |
| Function weighted effort | 42,475 → 42,386 | 51,497 → 51,445 |
| Component weighted effort | 47,626 → 47,538 | 60,534 → 60,485 |
| Mean locality | 75.3231 → 75.3631 | 77.1692 → 77.2020 |
| Mean leverage | 37.3385 → unchanged | 31.9066 → unchanged |
| Normalized clone groups | 108 → 107 | 167 → 167 |
| Clone-covered line union | 1,630 → 1,614 | 2,462 → 2,447 |
| `property var` declarations | 493 → 489 | 542 → 538 |

`DetailCard` observed uses increase **11 → 13**, but its leverage score was
already capped at 100. This is a modest reuse/locality improvement, not an
aggregate leverage-score gain. New safety tests absorb the 35 production lines
saved: total analyzed physical code is unchanged, and documentation adds lines.
No blanket repository-size reduction is claimed.

Expanded normalized-clone scans use 200,000 keys / 1,000 windows per key / 10,000
groups: **complete, zero omitted windows/groups** for both scopes/snapshots.
The ordinary configured clone report remains capped/partial. Complexity records
have no approximate functions. Weighted effort is advisory, not developer time
or Halstead effort: nested callbacks leave Halstead records incomplete (production
515 → 516), so no aggregate Halstead improvement is claimed. The maximum
handwritten production cyclomatic/cognitive values fall **57/100 → 27/32**;
generated schema validators remain at **65/97**. The heuristic score stays 82.

## Validation and remaining work

- Full native Qt: **395 passed, 0 failed, 1 existing RHI-only artwork skip**
  (totals include lifecycle hooks). Location suite: **24/0/0**. The new empty-ID
  regression also demonstrably fails on the frozen original implementation.
- Strict QML lint, runtime smoke, UI drift review and `git diff --check` pass.
  All 18 existing JavaScript check scripts pass, including generated contracts
  and packaged relative imports. No added style override or lint suppression.
- 4,096 frozen-baseline Bluetooth descriptor comparisons pass across capabilities,
  busy states, checked values and nullable wake support.
- The baseline full Qt attempt under concurrent analysis had one notification
  stack-count failure; its isolated unchanged suite rerun passes **11/0/0**.
  Do not count that full attempt as a clean baseline or a refactor-fixed defect.
- `measure all` is **not clean acceptance**: the first run lacked the existing
  `QML_XHR_ALLOW_FILE_READ=1` fixture prerequisite and timed out. A second run
  with it exceeded the outer 300-second bound during profiling; its remaining
  adapter process was stopped. Static comparisons and standalone native tests
  are separate completed evidence, not fabricated profiler/coverage results.

Follow-ups: generated schema-validator duplication belongs in the sibling
protocol generator, not hand-edited generated JS. Review `BatteryFlow`'s timeline
editing next against its safety tests. The tray `Status.qml` cleanup finding is
not dead code: `SystemTrayItem.qml` uses `Status.Active`. Semantic abstentions,
formatter/oracle limitations and profiling remain open. No full sibling-aware
Nix/release build, hardware, live compositor, IME or human accessibility acceptance
was performed.

Reproduce native checks from the declared development environment:

```sh
QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
python3 tests/review-panel-ui.py --base fba5e8a
```

The ignored `measure.mjs` runs Lens `createAnalysisContext` and `analyzeClones`
against `baseline.config.json` / `after.config.json`, disabling tool execution
and imported reports only for that matched static comparison. Original project
configuration and thresholds are unchanged; frozen metrics are in
`baseline/metrics.json` and `after/metrics.json` beside the logs.
