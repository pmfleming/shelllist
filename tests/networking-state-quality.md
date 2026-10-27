# Wi-Fi status QML quality checkpoint

Partial implementation remains partial: this is the mandatory quality/refactor
loop, not integration, all-networking completion or rollout approval. Original
baseline `6f14ede26d27cff03b72e51f647ee5e96dba6928`; implementation
`84a117f53eb4396f9db54520939aa41e8b221eab`; no seeds. Full baseline diff includes
production Wi-Fi QML/JS, all changed Qt/native tests, generated NM fixture and
qualification documentation.

Pinned qmlqualitylens source `97feb1f714c680ffcceedc935ecaa974d0c52cb1` (0.5.0),
aggregate dist-JS SHA-256
`b6443d1f0b8a610f73c79926080245e718f53ebaa0d903639bfb44df497b2a85`.
The owned static config retains project resolution context/rules and adds changed
e2e inputs, disables every execution adapter, and imports no stale reports. No
suppressions, threshold changes, allowlist expansion or analysis exclusions were
used. Test execution/lint is separate from Lens extraction.

## Actual findings and refactor rationale

BEFORE: 509 inputs, zero parser diagnostics and 1002 global advisory/static
findings. New `WifiController.applyRecoveredStatus` has a complexity.function
finding (cyclomatic 12/cognitive 12/24 lines; fingerprint
`55d3485b81641c3497770b72`). Native payload shape validation and the UI
cursor/publication transaction are combined in a nested predicate.

The refactor places the same wire-shape checks in the existing NmApiClient adapter,
with explicit unavailable, mandatory boolean/radio and nullable-object groups.
The controller still validates before the existing SnapshotCursor, and commits
its cursor before observable UI publication. No guard, unavailable behavior,
matching-producer requirement, field list, captured target, observer lifetime or
retry rule was removed. No backend method/schema runtime/policy fork was added.
Wire-shape enforcement is separated from rendering/editing publication; domain
facts remain native. Complexity merely moving between files is not claimed as a
universal quality improvement.

Retained findings include request completion/collection/gap orchestration, old
band presentation, API/size pressure, two normalized-clone hints and dynamic
JSON/test missing-type hints. Distinct malformed/old/quiet/reentrant/owner/draft
risks remain tested; no test was removed for clone/coverage/count goals. Keyboard,
Enter/Tab save, Escape discard and ordinary draft/no-write guards are unchanged.

## Comparable AFTER and affected checks

Same tools/config/scope: `applyRecoveredStatus` **12/12 -> 5/5** cyclomatic/cognitive;
the explicit API payload validator is **9/8**. These are local boundaries, not
additive scores or a claim that moving complexity makes it vanish. The transaction
no longer carries nested wire predicates; the adapter keeps every original field
check. The one introduced complexity finding is removed; global findings
1002 -> 1001, semantic findings remain 517. Parsing remains clean and static
resolution/semantic abstentions are unchanged. All remaining advisory findings
are retained rather than suppressed.

Private affected checks pass: **472 actual Qt passes, zero failed/one existing
renderer skip**, whole-tree/new native-entrypoint lint, generated contract and TS
companion parity, offline NM contract, build inputs and surfaces. All three native
Quickshell cases pass against current production QML/JS, with source/tool/binary
hashes retained. Producer tests remain 111 passes/four default ignored; strict
Clippy/formatting pass. No test or skip was removed/added to obtain these results.
Task-local Bash drivers passed bash -n; the projection Python passed py_compile
and bounded execution. These are language-specific checks, not Lens coverage.

Exact bounded driver: run's check.sh timeout 1800 bash
`tasks/02-networking-state/quality/run-after-checks.sh`; log `quality/after-checks.log`.
The subsequent clean-quality-head extraction and full identities are recorded in
task `quality/final`/quality reports; code stayed unchanged after affected checks.

## Evidence limits and reproducibility

BEFORE/AFTER/final raw envelopes, comparable configs, reviewer projections,
commands, source/tool hashes and functional logs live under
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/02-networking-state/quality/`.
The BEFORE static model has 17 unresolved types, 20 rule families with skips and
3687 skipped evaluations; normalized clone coverage is partial. Zero parse errors
and an internally complete type registry do not certify complete semantics or
execution. The Lens catalog discovers tests but does not execute/attribute them
under this static config. Actual private Qt/native checks complement, not erase,
those limitations. No TypeScript implementation changed; existing TS/generated
parity checks remain separate. Task-local Bash/Python drivers are outside Lens
certification and receive language-specific syntax/execution checks.

Exact AFTER comparisons, affected checks, clean quality-head identities and
remaining findings are recorded in the task's quality report. The existing
connectivity passive-read API request, inventory ordering, bar CQ-12 semantics,
generic non-status cache-refresh gap fallback and all other unfinished rows in
networking-state-qualification.md remain open. No default or deployment change.
