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
