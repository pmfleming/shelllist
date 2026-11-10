# Update controller quality review — 2026-11-10

Baseline: `b2a128bc`. Scope: update response dispatch, immutable history-window
validation, and the real Qt update interaction suite. Shared keyboard navigation,
request ownership, one-retry restart, cache limits, read-only commands, schemas,
and label timers retain their existing contracts.

The controller now reuses `UpdateValidation.runId`, uses optional property access
for response payloads, and handles non-retry history errors in one branch. The
translated error table is constructed only on rejection. Continuation validation
expresses the acceptance conditions together without changing their bounds.

## Comparable lens evidence

Used the local `qmlqualitylens` at `97feb1f714c680ffcceedc935ecaa974d0c52cb1`,
compiled once into ignored `target/update-quality/lens`. Both inputs are complete
`git archive b2a128bc` snapshots; the after snapshot overlays the three changed
source/test files. Neither snapshot contains `.git`; history/churn is unavailable
on both sides. Source roots, generated files, entrypoints, dynamic edges and
exclusions are identical. No baseline or threshold was changed.

Evaluator fingerprint:
`ecbe448644080d95c83fc67b09fdf409d983163a2b5166d7b7eeb2585c605655`

Config SHA-256 after omitting only the output directory:
`f9b402f5918f6eb9204b67eaed8cfa3ef9ecf0923f10fea5d6af7993fce37486`

Ran `measure` for `quality.qml`, `quality.locality_dynamic`,
`quality.locality_leverage`, `quality.clones`, `quality.cleanup` and
`correctness.catalog`. Artifacts and logs are in
`target/update-quality/{before,after}-evidence` and sibling log files.
Static configuration disables qmllint/report ingestion equally; actual Qt and
strict qmllint checks run separately below.

| Measure | Before | After |
| --- | ---: | ---: |
| Changed production files, physical LOC | 582 | 577 |
| Changed production functions/handlers (same denominator) | 63 | 63 |
| Their cognitive / cyclomatic / lens effort sums | 207 / 260 / 1109 | 200 / 253 / 1082 |
| Their measured Halstead effort (49 of 63 functions) | 103286.29 | 98921.40 |
| All 17 `bar/Update*` files, physical LOC | 2282 | 2277 |
| All 161 update functions, cognitive / cyclomatic / effort | 510 / 647 / 2615 | 503 / 640 / 2588 |
| Update test file, physical LOC | 1651 | 1640 |
| Update test bodies (excluding data providers) | 42 | 41 |
| Full lens source lines (544 files, unchanged scope) | 59891 | 59875 |
| Controller locality / leverage scores | 0 / 30 | 0 / 30 |
| Controller process-boundary violations | 0 | 0 |
| Full lens clone groups (partial detection) | 145 | 145 |
| Full lens cleanup findings | 9 | 9 |
| Parser diagnostics | 0 | 0 |

The heuristic complexity/effort gains are modest. `stageHistoryPage` Halstead
effort increases from 2428.91 to 3069.32; the same measured function population
still improves overall. Locality and leverage scores do not improve; reuse of the
existing ID validator removes one literal rule copy without adding a dependency.
No dead-code or clone-group reduction is claimed. Cleanup hints include dynamic
test-platform exports and are not proof of dead code. No suppression, ignore,
dynamic evaluation or new error-swallowing fallback was added. This report is
additional documentation, excluded from the source/test LOC reduction of 16 lines.

## Executed behavior evidence

With the cached Nix environment (`source .direnv/flake-profile-*.rc`):

- `tests/run-qmlquality-tests.sh -input tests/qml/tst_updates.qml`: baseline
  49 passed; after 48 passed, zero failed/skipped (both include lifecycle hooks).
- `tests/run-qmlquality-lint.sh -I "$PWD/qml" -I "$PWD/tests/qml/imports" --
  bar/UpdateController.qml tests/qml/tst_updates.qml`: passes with zero warnings.
- `git diff --check`: passes.

Removed the redundant exact-link/close fixture and the stale-cursor test's second
close scenario. Cache clearing and late replies remain owned by
`test_historyCacheCloseDropsPublishedAndStagedPayloads`; exact target selection,
filter bypass and retained-target reopening belong to
`test_historyWindowNavigationKeepsFiltersAndExactLinksIndependent`.
This removes duplicate executions, not just test registrations.

That navigation test now rejects empty, path-like, leading-hyphen and 161-character
IDs without reads or state changes. The existing native Alt+V retry journey now
also rejects absent log data and a 32769-character log, while preserving the
independent history error and retiring log loading.

Controlled fault injection used disposable before/after snapshots only: remove
the `openRun` validation return and the `log.text.length > 32768` rejection. Run
only the navigation test above and `test_logLoadingAndFailuresStayWithTheirRun`.
Baseline tests pass both faults; revised tests fail both (unexpected history read
and absent invalid-log error). Restore both snapshots afterward. Logs:
`target/update-quality/{before,after}-fault.log`. The unmodified final suite passes.

These are executed behavioral and fault-detection improvements. Qt line/branch
coverage was not instrumented, so no numerical coverage increase is claimed.
Single-run durations are not a performance benchmark. The existing bounded cache,
no-backend-polling timer and keyboard/safety cases continue to execute in the suite.
