# Shelllist quality campaign, 2026-10-30

Baseline: `62f31cbb89e5865acaf2b1ef6fb0ec05e85d25ca`, clean working tree.
Only this repository is owned; no dependency, protocol, fixture, deployment or
live-setting changes. Required panel reference documents were read locally.

## Evaluator and scope

- QMLQualityLens 0.5.0, sibling source HEAD
  `97feb1f714c680ffcceedc935ecaa974d0c52cb1`, existing compiled evaluator.
- `qmlqualitylens.config.json` SHA-256
  `64404e44991983d30f01fcf36c99f2f3c4e5380ec9ad31af2b3312d10a5d3ef1`;
  roots, exclusions, policies and dependencies stay unchanged.
- Static commands use host Node 24.18.0:
  `node ../qmlqualitylens/dist/bin/qmlqualitylens.js analyze --config qmlqualitylens.config.json --format summary`
  and `measure quality.locality_leverage --config qmlqualitylens.config.json`.
- Native checks use the existing Nix development environment:
  `bash -c 'source .direnv/flake-profile-*.rc; COMMAND'`.
  Qt 6.11.1, Quickshell 0.3.0, Python 3.13.13; offscreen/software/UTC
  and matching SVG/font/timezone inputs come from the repository runner/environment.
- Raw reports/logs: ignored `target/quality-campaign-20261030/`.
  The exploratory `measure all` was terminated during tool checks, **not passed**;
  baseline/final static analysis and explicit native gates are recorded separately.
  Its dead-writer lock was archived only after confirming the writer had exited.

## Initial stage

Agenda detail dispatch is the highest non-generated production cognitive hotspot
(59, cyclomatic 18). Replace the growing `else if` action chain with direct
`switch` dispatch in its existing owner. Keep modal, write/delete, retry, native
acknowledgement and draft boundaries unchanged; no new navigation or visual roles.
Existing `tst_agenda.qml` native command/save/confirmation journeys own behavior.

Initial validation: strict lint of `activity/AgendaController.qml` passes;
`run-qmlquality-tests.sh -input tests/qml/tst_agenda.qml` with
`Agenda::test_nativePrimaryAndActionFreeInspection`,
`Agenda::test_atomicScheduleDraftFailureClearAndReopen`,
`Agenda::test_sharedCreationDayDefaultsAndOutsideScopeInspector`,
`Agenda::test_threeTabsChecklistIndependentAndConfirmedDelete` and
`Agenda::test_realBridgeStaleReadsAndReceiptWithoutMutationReplay`:
**7 passes (5 behaviors + 2 lifecycle hooks), zero failures/skips**.
Cognitive 59 → 21; cyclomatic 18 → 18; source lines +4;
token Halstead effort 8767 → 8793. This small effort/size increase is an explicit
tradeoff for direct action dispatch; no branch or guard was removed.

Baseline full Qt: **696 passed, 2 failed, 1 existing renderer skip**.
Both failures precede implementation in `tst_application_actions.qml`:
`test_close_usesNativeObservationAndRestoresCommandFocus` line 204 (null command)
and `test_pagedWindowRefreshPreservesIdentityAndPendingGuards` line 176
(delegate absent immediately after `wait(0)`). Baseline strict lint passes.
The baseline full runner started against clean sources; Agenda's cases completed
before the initial Agenda-only edit. Static baseline reports were frozen before
any production edit. Baseline `local-build preflight .` passes.

## Ranked next five (post-initial report)

1. **Socket response flow** (`receive`, cognitive 40 / cyclomatic 31): return
   early for non-response records, keeping one flat response-validation path.
   Preserve correlation, late-resource cleanup authority, uncertain permits,
   retirement-before-callback and no-replay guards. Highest remaining
   non-generated cognitive hotspot; existing socket journeys own these risks.
2. **Socket admission scans and credit policy** (`write` 30/30, `pump` 26/16):
   share the actual dispatch-credit rule across admission/pumping and stop
   allocating filtered arrays just to count queued requests/control bytes.
   This affects every shared owner and has exact boundary/cleanup tests.
3. **Update history capture** (`requestPage` 31/25): name the retained-page
   continuation decision once and remove its unnecessary shallow entries clone.
   Published entries are replaced, never mutated; the existing pure window
   transition concatenates pages. Bounded refresh/anchor/restart journeys own it.
4. **Clipboard operation retention** (`acceptOperation` 22/21): replace repeated
   full-key enumeration while pruning with one excess count. Preserve every
   running operation and the just-accepted record, even above the soft cap.
   Add native recovery-boundary cases for terminal/running/mixed populations.
5. **Native test setup and lifecycle**: remove duplicated fixture-loader/clone
   implementations in the three producer-contract suites using their existing
   `DaemonTestCase` owner; retain every behavior/assertion. Diagnose/fix the two
   reproducible Applications test failures against actual asynchronous delegate
   readiness and the shared responsive disabled-command contract. Prefer this
   demonstrated reliability/duplication work over speculative dead-code removal.

No static reachability suggestion establishes removable code: public exports,
generated validators and transport guards remain. No helper extraction is used
solely to split metric totals; shared helpers must own a reused operation/rule.

## Stage 1 — socket response flow

Flattened `JsonlSocketTransport.receive` without splitting its validation owner.
All malformed/correlation/route checks, unknown-outcome credit retention,
late-resource handling and callback order remain in place.
`run-qmlquality-tests.sh -input tests/qml/tst_daemon_socket.qml -o -,txt`:
**24 passes (22 behaviors), zero failures/skips**; strict lint of the changed
transport and `git diff --check` pass. Raw `stage1-qt.log`, `stage1-lint.log`.
Measured `receive` cognitive 40 → 32; cyclomatic 31 → 31; token Halstead effort
39812 → 39812. This is a control-flow readability improvement, not fewer guards.

## Stage 2 — socket admission

`dispatchReady` now owns the reused call/control credit decision for admission,
dispatch and queued follow-up. Removed two temporary filtered arrays used only
for counting queued records/control bytes. Queue and byte ceilings, reserved
cleanup space, FIFO lanes, generation fences and callback order are unchanged.
Do not snapshot pending records across `discardQueued`: its callbacks can reenter.
The same full socket suite passes **24 / 0 / 0**, including exact control slot,
queue and byte reservations, delayed expiry, uncertain permits and late receipts.
Changed-file strict lint and `git diff --check` pass. Raw `stage2-*.log`.
No wall-clock or throughput improvement is claimed from allocation removal.

## Stage 3 — Update history capture

Named the shared continuation decision once and removed `entries.slice()` when
capturing an append prefix. Source review found no in-place mutations of published
entries; `UpdateHistoryWindow.advance` concatenates and returns a new window.
The retained native refresh journey now independently checks that the captured
50-row prefix remains unchanged after the 100-row publication. The cache contract
documents that invariant. No page cap, anchor, revision or retry guard changed.
Full Updates suite: **47 passes (45 behaviors), zero failures/skips**;
changed controller/test strict lint and `git diff --check` pass. Raw `stage3-*.log`.

## Stage 4 — clipboard operation retention

Pruning enumerates keys once and decrements an excess count only after deletion,
instead of allocating/enumerating the full key array on every visited record.
Iteration order, 64-record soft target, running-operation protection and protection
of the just-accepted record are identical. Native recovery-boundary data cases
submit 71 owned operations each for terminal, running and mixed populations;
they check exact retained totals, protected records and no extra effect calls.
The full clipboard stream-recovery suite and changed-file strict lint pass;
see `stage4-qt.log` / `stage4-lint.log`. Three new behavior rows add coverage of
retention limits; no statement/branch coverage percentage is claimed.

## Stage 5 — native fixture ownership and readiness

Seven suites share `DaemonTestCase.readFixture`; the three cached producer-contract
suites retain an explicit cached fixture property and share its deep-clone helper.
Application action receipts reuse the same loader. Fresh reads remain fresh;
cached fixtures remain consumer-owned, and producer fixture bytes are unchanged.
No test function/data row was removed, no assertion family was retired, and no
discovery/skip policy changed. All checks of commands, IDs, native outcomes,
capability guards and field traversal remain.

The two clean-baseline failures reproduce in isolation. Tests now wait for actual
page delegates/navigation readiness instead of treating `wait(0)` as completion.
The pending-Close test checks the row's guard, attempts both guarded row commands,
and clicks any rendered disabled buttons; shared narrow rows are allowed to omit
disabled buttons. The single-call assertion remains. Contended reruns exposed
the same readiness assumption in the last desktop-action page and passive-page
focus, and an immediate partial-delegate count. Their expected identities/counts
are now awaited, not relaxed. A 10 ms control-queue test could expire during setup:
it now fills under a long deadline, checks all existing capacity assertions, then
expires those queued records through real Qt timers. The separate deadline test
still owns automatic wall-time expiry.

Focused final native suites: **ApplicationActions 27 passes (25 behaviors)**,
**DaemonSocket 24 passes (22 behaviors)**, no failures/skips; full strict lint
passes (`stage5-settled.log`). Introduced helper parameters/returns are annotated;
strict lint and the final Lens retain all existing policies.

## Fault evidence

Only the ignored `fault-source/` archive was mutated. Removing running protection
makes the new clipboard rows fail twice (running/mixed); removing current-record
protection fails once (running). After restoration the three rows pass (five Qt
checks including hooks), and the archived implementation byte-matches production.
`fault-running.log`, `fault-current.log`, `fault-restored.log` record the results.

## Matched measurements

Baseline/final `analyze` reports have identical evaluator fingerprint
`ecbe448644080d95c83fc67b09fdf409d983163a2b5166d7b7eeb2585c605655`
and effective config hash
`682b17d2340cb2ccdf21beaec03790ae38aaf83923b49b7c122346cccc720594`.
Compiled entrypoint SHA-256 is unchanged:
`03cd63e3ca16f990e340f2eabee396e8bbfbf8a1606acdd172f20f4b8ba831e5`.

| Metric | Baseline | Final |
| --- | ---: | ---: |
| Lens files / components | 531 / 455 | 531 / 455 |
| Lens source lines | 57884 | 57876 |
| Functions/handlers | 4532 | 4527 |
| Parser diagnostics | 0 | 0 |
| Advisory findings | 1139 | 1138 |
| Overall / locality / leverage score | 82 / 76 / 31 | 82 / 76 / 31 |
| Leverage high / central-risk classifications | 65 / 56 | 64 / 57 |
| Tracked non-`tests/` code physical LOC | 61752 | 61762 |
| Tracked `tests/` code physical LOC | 18316 | 18304 |
| Combined physical LOC | 80068 | 80066 |
| Qt behavior inventory (including existing skip) | 567 | 570 |

Tracked code counts use exactly `qml js mjs ts rs py sh nix` extensions from
`git ls-files`, counting symlink contents as Git-listed code and a final
unterminated line once. Non-`tests/` includes tooling/dev/generated code and
inline Rust tests: it is a reproducible repository census, not pure runtime LOC.
Nonblank counts: non-`tests/` 58752 → 58761; `tests/` 17986 → 17973.
Raw census definitions/results are `baseline-loc.json` and `final-loc.json`.
Stage 5 alone removes 35 test-code physical lines; new retention cases and
readiness checks account for the smaller net repository reduction.

| Production function | Cognitive before → after | Cyclomatic before → after |
| --- | ---: | ---: |
| Agenda `triggerDetailAction` | 59 → 21 | 18 → 18 |
| Socket `receive` | 40 → 32 | 31 → 31 |
| Socket `write` | 30 → 28 | 30 → 28 |
| Socket `pump` | 26 → 19 | 16 → 14 |
| Updates `requestPage` | 31 → 29 | 25 → 23 |
| Clipboard `acceptOperation` | 22 → 22 | 21 → 21 |
| New shared socket `dispatchReady` | absent → 3 | absent → 3 |
| **These owners including the new helper** | **208 → 154** | **141 → 138** |

Tradeoffs/limits: clipboard's complete token Halstead estimate rises
38591 → 44269 despite eliminating repeated key enumeration; Updates falls
27418 → 25758. Socket `write`/`pump` Halstead is **incomplete** (nested syntax),
not zero effort. No complete global effort gain is claimed. `DaemonTestCase`
still scores 100 leverage with 46 consumers, but its 78 → 85 implementation
lines move its advisory effort over the central-risk threshold (96 → 104).
Keeping fixture I/O/cloning with the existing recording-transport test owner is
preferable to another helper hierarchy. Global rounded scores stay unchanged.
Clone reports remain capped/partial at 100 groups; omitted groups 80 → 76 are
not proof of four removed clone groups. Semantic skipped evaluations
3939 → 3942 remain explicit; no policy was weakened.

## Final gates and limits

Run the following in the Nix development environment described above:

| Command | Result |
| --- | --- |
| `bash tests/run-qml-tests.sh` | **701 passed, 0 failed, 1 existing RHI-only artwork skip**, `final-verified-qt.log` |
| `bash tests/run-qmllint.sh` | Pass, full strict source-tree lint |
| `node tools/build-typescript.mjs --check` | Pass, generated-source freshness |
| `tsc --project tsconfig.json` | Pass |
| `node tests/check-generated-contracts.js .` | Pass, generated wire replies/invalid requests/payload mutations |
| `node tests/check-packaged-imports.js .` | Pass, source-relative import graph (not a package build) |
| `node tests/check-ip-control.js qml/Shelllist/Ui/IpValidation.js qml/Shelllist/Ui/IpEdit.js` | Pass, 450 checks |
| `python3 tests/review-panel-ui.py --base 62f31cbb89e5865acaf2b1ef6fb0ec05e85d25ca` | Pass, zero changed-line/new-wrapper prompts; no numeric visual exceptions |
| `bash tests/run-runtime-smoke.sh` | Pass, existing offscreen window-mask warning |
| `CARGO_BUILD_JOBS=2 local-build build --attr checks.x86_64-linux.qmlLint . --offline --no-link --cores 2 --max-jobs 2` | Final current-source attempt blocked before build by sibling untracked files |
| Same command with `checks.x86_64-linux.qmlTests` | Same external blocker; not passing package evidence |

Exact external blocker, preserved without staging/editing: `update-daemon/`
`crates/shelllist-update-status/default_14324535524229848502_0_1495703.profraw`
and `tests/support/config.rs`. See `final-current-package-{lint,qt}.log`.
The final `local-build preflight .` still fails for that sibling and additional
coverage-generated `*.profraw` files (`final-preflight.log`); none were touched.
Earlier provisional Nix lint snapshots passed; obsolete Qt package snapshots
were cancelled before testing when sources changed. They do not qualify the
final tree. No sibling pin/lock changes were made; no direct flake evaluation
was used. `nix log` only inspected a dependency build log.

Raw `final-frontend-gates.log` holds the generation/IP/import/UI/smoke results;
`stage5-settled.log` holds strict lint and focused final native regressions.
The first broad final Qt attempt was **700 passed / 1 failed / 1 existing skip**
(`final-qt.log`); its additional last-desktop-action readiness failure was fixed.
Contended exploratory socket/Application runs also remain as failed evidence,
not passing reruns (`final-typed-helpers.log`, `stage5-final-focused.log`,
`stage5-complete.log`). No new skips were introduced to make validation green.

Execution counts are behavior inventory, **not numeric code coverage**. No new
profiler/statement/branch coverage measurement, controlled performance benchmark,
hardware mutation, live compositor, IME or human accessibility acceptance was
performed. Producer protocol bytes, dependency versions, public APIs, saved-field
navigation and safety/acknowledgement/retry semantics remain unchanged.

Final execution: **569 passed behaviors + 132 lifecycle hooks**, one unchanged
`qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()` skip.
The baseline had 564 passed behaviors, two failures and that skip. The native
test-function set loses no names; one new data-driven function adds three rows.
The unchanged `count-test-inventory.py` reports 625 mixed inventory units:
570 Qt rows, 35 JavaScript assertion sites, 15 declared Rust tests, zero matching
Python test declarations and five daemon-contract declarations. This is not a
claim that the Rust/producer suites ran here. Reproduce with
`python3 tests/count-test-inventory.py --qml-log target/quality-campaign-20261030/final-verified-qt.log --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'`;
the result and repeated zero-prompt UI review are in `final-inventory-and-ui.log`.

## Parent integration follow-up

After all eight workers committed and their trees were clean, the parent ran
`local-build check .` against one captured graph: **all 28 checks passed**,
including packaged Qt (**701 passed, zero failed, one existing skip**).
This resolves the sibling-file package blocker above. The [campaign overview](quality-campaign-overview-20261030.md)
records exact source identities, command, logs and remaining quality-policy limits.
