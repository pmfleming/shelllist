# QML QualityLens review and refactor — 2026-11-05

Baseline `a8848405`; implementation commits `d3b13b9`, `984f95e`, `fadbf8e4`.
The worktree was clean at baseline. No sibling repository, generated protocol,
quality configuration, discovery rule, test counter or skip policy was changed.

## Review and implementation

The local `../qmlqualitylens` evaluated all 540 discovered files, including tests
and generated code. Highest authored-code risks included socket admission and
response handling, Agenda details, notification paging and session receipts.
The largest overall function is generated schema validation; it remains owned
by the framework generator. Generated clone windows and platform test doubles
are not evidence of removable production code.

1. **Shared I/O:** receipt admission now belongs beside the existing resource
   disposition logic in `SubscriptionCleanup`. Session routing retains view
   delivery, publication and cleanup scheduling. One base-subscription reset is
   reused across restoration, owner retirement and failure. Mandatory client
   lifecycle hooks replace four optional feature checks; all recording clients
   implement those hooks. Bridge/socket paths share correlation shape validation.
   Socket admission calculations are separated from request capture/publication.
   Dispatched acknowledgements no longer filter/copy an already-updated queue.
   Captured bytes/routes, uncertain native permits, reserved cleanup capacity,
   bounded queues, synchronous reentrancy and no-replay guards are retained.
2. **Notification pages:** staged rows, watermark and offset are one unpublished
   value. Owned completions consume it once; validation precedes staging or
   publication. Exact-app scans discard prefixes without losing their next offset.
   Publication has a separate small owner. Notification tests now create real
   owned reads and complete them through `NotificationBackend.finish`; they no
   longer call the page-acceptance helper directly. This also corrected a test
   whose supposed initial accepted page actually had an invalid offset.
3. **Existing reuse and dead code:** Agenda saves/rebases/removes submitted drafts
   through `Core.DraftStore` with a read-only alias, retaining immutable begin
   snapshots and domain acknowledgement. Bluetooth removes its duplicate map-copy
   helpers in favor of `BtApi`, already used by operation recovery. Three confirmed
   unused IDs are removed; exported types/platform test doubles are retained.

The tracked [ownership contract](../contracts/qml-state-ownership.md) records the
boundaries. No key model, field-save boundary, domain guard or visual role changes.

## Matched metrics

The authoritative comparison uses the Lens checkout's `scripts/compare-refactor.mjs`:
archives of both commits, a frozen evaluator, identical tracked configuration and
one Node/Qt environment. Native execution/report imports are disabled for both
static captures. The same frozen evaluator also measured all static artifacts
against those archives. Evaluator fingerprints match:
`857cd4a335adb086d1d37ba54350628048b261f17874d0b7f2867abb9399b159`.
Initial exploratory reports used a different Node environment; they are not the
basis of the comparison. No analyzer or policy was modified to improve scores.

| Authored QML owner | Peak cyclomatic before → after | Peak cognitive before → after |
|---|---:|---:|
| DaemonSessions | 22 → 17 | 21 → 18 |
| JsonlSocketTransport | 28 → 24 | 28 → 24 |
| NotificationCatalog | 24 → 17 | 26 → 18 |

Across authored production function records (excluding tests, dev and generated
files), descriptive sums change as follows. Helper implementations remain in the
scope, so moving code to JS does not remove its cost from these sums.

| Metric | Before | After |
|---|---:|---:|
| Sum of per-function cyclomatic values | 10,764 | 10,754 |
| Sum of per-function cognitive values | 7,669 | 7,655 |
| Sum of Lens weighted effort values | 46,958 | 46,907 |
| Maximum function cyclomatic | 28 | 25 |
| Maximum function cognitive | 28 | 27 |
| Lens discovered source lines | 59,074 | 59,023 |
| Production physical lines in discovered inventory | 48,069 | 48,063 |
| Test physical lines in discovered inventory | 14,625 | 14,583 |

Function sums are descriptive; weighted effort is neither developer time nor an
aggregate Halstead calculation. Unsupported/nested Halstead bodies remain
incomplete, never zero. The overall advisory score stays **82**.

Reuse/locality results are mixed, not a claim of whole-project convergence:

- `DraftStore` observed uses **5 → 6**, leverage **75 → 90**.
- `NotificationCatalog` locality **87 → 88**; `ApplicationPage` **73 → 74**.
- Agenda locality **12 → 7**, from its new explicit shared-state dependency;
  its component effort rises **1352 → 1356**. This is the accepted reuse tradeoff.
- Rounded project leverage/locality scores remain **31/76**. Binding/cohesion
  graphs still contain incomplete resolution and cannot certify architecture.
- Unused-ID findings **3 → 0**. Eight platform-fixture reachability findings
  remain. Clone groups stay **145**, with partial detection. Real duplicate
  helpers/reset logic were removed, but no aggregate clone reduction is claimed.

## Stronger protection with less test code

The socket opt-in behavior has one primary native owner. Its duplicated
clipboard/bar exact-value tests are removed; that owner now checks empty, `0`,
`true`, `1` and daemon isolation for **all five** supported flags. The previous
non-exact-value checks covered only bar/clipboard. These remain explicit input
vectors, not a claim that test-count reduction measures coverage.

Notification restart/stale-page tests retain their behaviors while completing
actual owned reads instead of bypassing envelope/ownership handling. Existing
cleanup, paging, draft, Bluetooth recovery and interaction suites remain intact.
No new skips, exclusions, hidden test names or counter changes were introduced.

| Native Qt inventory | Before | After |
|---|---:|---:|
| Executed behavioral cases | 597 | 595 |
| Existing renderer-only skipped case | 1 | 1 |
| Lifecycle hooks (excluded from behavior inventory) | 136 | 136 |
| Runner passes including hooks | 733 | 731 |
| Established mixed inventory units | 656 | 654 |

The 42-line test reduction includes recording-client hook additions. Coverage
improvement is demonstrated by behavior and fault sensitivity, not an invented
branch/line percentage. In disposable archived sources:

- Relaxing NM's exact socket opt-in to any nonempty value: **old suite passed**
  all 24 checks; revised suite **failed** its opt-in behavior. Restored candidate
  passed all 22 checks. This establishes a newly protected failure mode.
- Ignoring receipt protocol identity: four intended cleanup assertions failed,
  including a peer-resource authority check. Restored suite passed 32 checks.
- Losing the exact-app scan offset: the bounded exact-lookup journey failed
  because scanning stopped before its owned continuation. Restored suite passed
  10 checks. No compilation/import failure was counted as defect detection.

Paired Qt profiler observations were captured for socket, cleanup, cache and
notification suites. They observe QML creation/binding/handler execution and
include fixtures/setup/teardown; they do not measure branch coverage, standalone
JS function coverage, meaningful assertions or display frame timing. Fake daemon
boundaries do not establish native daemon behavior or persistence.

## Validation and reproducibility

Final serial full Qt: **731 passed, 0 failed, 1 unchanged software-renderer skip**,
Qt 6.11.1 with matching fonts/SVG imports. Strict whole-tree QML lint passes.
Generated contract request/reply mutation checks, source-relative import checks,
450 existing IP-control assertions and native offscreen runtime smoke pass.
Panel UI review reports zero new numeric-style or wrapper prompts.

Focused runs additionally covered Agenda (63 checks), Agenda cache (6), Bluetooth
operations (31), daemon session/boundary/metadata, cleanup, socket and notification
center/cache. An early session-loop simplification left an undefined consumer
ID; Agenda's warning gate caught it. It was corrected before final validation.
Initial ad-hoc import/IP-script calls omitted required CLI arguments; corrected
commands passed. Those invocation errors were not acceptance evidence.

Reproduce in the cached development environment:

```sh
source .direnv/flake-profile-a5d5b61aa8a61b7d9d765e1daf971a9a578f1cfa.rc
tests/run-qmllint.sh
tests/run-qml-tests.sh
node tests/check-generated-contracts.js
node tests/check-packaged-imports.js "$PWD"
node tests/check-ip-control.js qml/Shelllist/Ui/IpValidation.js qml/Shelllist/Ui/IpEdit.js
tests/run-runtime-smoke.sh
```

Raw artifacts are ignored under `target/quality-review-20261105/`: frozen archive
comparison and `*-static/` reports, `metrics.json`, full/focused logs, profiler
captures, before/after inventories and fault/restoration logs. The source-import
check is not a packaged Nix build. No new full sibling/package build, hardware,
production compositor, accessibility/IME or live mutation acceptance is claimed.
Remaining high-complexity owners, partial clone detection and mixed locality are
follow-up work rather than suppressed findings. Nothing was pushed or deployed.
