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

Subsequent stage ranking and measured results follow after the initial commit.
