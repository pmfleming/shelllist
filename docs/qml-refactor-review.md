# QML quality review: shared feature boundaries

Measured with the local `../qmlqualitylens` 0.5.0 checkout, Node 24.16.0 and
Qt 6.11.1. The baseline is the incoming worktree at `b688864`, **including its
existing uncommitted changes**, not pristine HEAD. Those changes are retained.

## Changes and rationale

- **All five feature backends:** use the existing typed `DaemonBackend`
  properties directly, matching activity/battery/displays. Remove the untyped
  `endpoint` object, its fallback/conversion branches and duplicated property
  names. `daemonName` is required; streams are `list<string>`.
- **Shared transport:** eliminate forwarding-only response/event/failure methods
  and the redundant subscription-ID lookup. Keep pending-request clearing,
  delayed subscription cancellation and transport-loss ownership in one place.
  Do not combine domain-specific response policies: Wi-Fi's error results,
  clipboard leases, Bluetooth pairing and bar OSD failures have different needs.
- **Bluetooth:** separate device acknowledgement and audio-profile persistence
  from response orchestration. Preserve the captured device identity, error
  messages and apply-before-remember ordering. Initialize operation maps before
  bindings evaluate; remove trivial counting/event wrappers.
- **Wi-Fi:** bind routing tables to QML methods instead of forwarding closures.
  This keeps dispatch next to its existing owners without introducing a generic
  routing framework or moving branches into another language.
- **Chooser surfaces:** replace four untyped loader-result properties with
  `ChooserListPane`/`Item`; Bluetooth explicitly casts its detail pane. Dynamic
  payloads and asynchronous Loader creation remain intentional boundaries.
- **Top bar:** workspace buttons reuse `ActionControl`, adding the same
  keyboard, assistive activation and disabled/busy policy as chooser controls.
- **Real recovery bug:** work-area `lagged` handling was unreachable because
  `DaemonBackend` consumes gaps before emitting `eventReceived`. Connect
  `eventGapDetected` instead and test through the backend's event boundary.
- **Cleanup/reuse:** remove the genuinely unused `Theme.animationSlow` token.
  Consolidate six tests' transport isolation behind `DaemonTestCase`; retain
  every behavioral scenario. The test-only icon stub supplies geometry, not
  rendering evidence. Explicit lens entrypoints identify tests whose root now
  derives from `TestCase`; no sources, rules or findings are suppressed.

## Measurements

All-source figures include QML tests and generated JavaScript in the existing
lens configuration. Function metrics below are sums, not rounded quality scores.

| Metric | Before | After |
| --- | ---: | ---: |
| Lens source lines | 35,672 | 35,498 |
| Production source lines | 30,359 | 30,279 |
| Function cyclomatic sum | 7,017 | 6,982 |
| Function cognitive sum | 5,514 | 5,506 |
| Function effort sum | 34,991 | 34,868 |
| High-risk components | 52 | 50 |
| High-leverage components | 49 | 51 |
| Cleanup findings | 85 | 84 |
| Bluetooth `finish`: cyclomatic / cognitive / effort | 14 / 22 / 96 | 8 / 11 / 54 |

Production-only function sums also improve: cyclomatic **6,526 → 6,518**,
cognitive **5,183 → 5,178**, effort **30,581 → 30,537**. Shared `ActionControl`
uses increase from 6 to 7. The new test fixture has leverage 100 and locality 92;
Bluetooth/clipboard recovery-test locality improves from 38/76 to 48/84.

Limits/tradeoffs: the rounded overall score remains **85**, locality **77** and
leverage **50**; the low-locality count remains 50. WorkspaceButton's extra shared
component dependency slightly lowers its local heuristic score (77 → 75), in
exchange for tested activation behavior. Clone detection is **partial/capped**
in both runs: 200 reported groups are not an exhaustive clone count. Reported
repeated-line pressure for Bluetooth/clipboard/Wi-Fi recovery tests falls from
138/98/110 to 24/8/40, but whole-project files with reported duplication increase
181 → 184 as other groups enter the bounded report. Do not claim a global clone
percentage improvement. Generated protocol tables and live controller properties
flagged heuristically as unused were deliberately retained.

## Validation and reproduction

```sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all --config qmlqualitylens.config.json
tests/run-qmllint.sh
tests/run-qml-tests.sh
node tests/check-daemon-boundary.js .
node tools/build-typescript.mjs --check
```

- Native warning-fatal lint: passed; lens parser diagnostics: zero.
- Qt Quick Test: **256 passed, zero failed/skipped**, versus 255 before (totals
  include setup/cleanup). Added workspace activation; expanded subscription
  cancellation and work-area recovery assertions. Existing tests were not removed.
- Lens-managed offscreen runtime smoke: passed, zero runtime-warning findings.
- JS daemon-boundary, Bluetooth lifecycle, clipboard actions, bar presentation,
  application history and flow-policy checks: passed. TypeScript generation: passed.
- Full Nix/daemon-contract gate and live-hardware validation were not run.

Local raw evidence is under `target/refactor-review/{before,after}/`; the original
worktree patch is `target/refactor-review/pre-existing.patch`. These are ignored
artifacts. Formatting drift remains 97 files; broad reformatting was avoided.

Remaining review priorities: `ApplicationResourceLaneChart.validSegments`,
Bluetooth adapter-settings binding pressure, and Wi-Fi's large response table.
They warrant separate behavioral refactors, not a forced common response/UI
abstraction just to improve aggregate scores.
