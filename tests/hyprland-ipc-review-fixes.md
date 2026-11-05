# Hyprland IPC review follow-up — 2026-11-05

Scope: the coordinated framework/app/bar/Shelllist commits listed in the local
`docs/hyprland-ipc-gaps-review.md`, checked against current clean main checkouts.
This tracked record supersedes the original plan's stale “not started” status.
Local `docs/` remains ignored. No deployment, service restart or push is required.

## Closure plan

1. Move bar pin-prefix recovery out of journal loading and immediately before
   first pin admission (both close snapshots and replacement handoffs). Keep
   failed cleanup retryable and reads independent of capability probes.
2. Record every manual window move, including special and named destinations,
   so returning/closing before reconciliation cannot resurrect a handoff.
3. Correct numberless named-workspace parsing and consumer reads/launch routing.
   Capture a private 0.57.1 fixture and test real event/address semantics. Keep
   temporary allocation, close and replacement guards restricted to numbered
   destinations; never fabricate an ID for a named workspace.
4. Remove the test-only special toggle API from mandatory production capabilities;
   validate it separately in private acceptance. Accept valid version suffixes
   without weakening the 0.57.1 floor or the actual API probe.
5. Reuse an exact-session app IPC client so successful capabilities are cached
   across mutations, with failure retry and session boundaries covered by tests.
6. Format the portal launcher, run the coordinated suites and private acceptance,
   and record outcomes and remaining rollout checks. Commit each closed item in
   every affected repository before moving on.

## Review decisions

- Issues 1–5 are actionable. Issue 6 is preventive hardening, worth doing with a
  small version-parser regression. Portal formatting (7) belongs with its fix.
- Leave the short app/bar shutdown latches separate: shared abstraction would
  couple distinct service owners without changing behavior or fixing a defect.
- Remove the obsolete legacy special-ID heuristic when touching workspace
  identity. Keep `urgent` in the existing bar wire contract for compatibility;
  stock Hyprland workspace JSON supplies no urgency value.
- Production restart, docking, suspend/hibernate and real non-UTF-8 client titles
  remain rollout checks. Private acceptance cannot certify physical recovery.

## Evidence and closure

The scoped fix plan is complete. All changes are committed locally. Named
lifecycle extensions and physical/production rollout checks remain explicitly
deferred as described below.

### Reads, handoffs and named identities closed

- Bar `eb314b7`: deferred prefix cleanup; 23 lifecycle tests pass.
- Bar `24c38a9`: record special/named moves; 26 workspace tests pass.
- Named identity closure spans framework, bar, app and portal. Private installed
  0.57.1 acceptance passed; captured named JSON/events now live in the framework.
  Full framework/bar/app tests pass, plus the new app process launch regression,
  five portal tests and five Qt strip checks (including init/cleanup).
- The review missed geometry's legacy negative-ID `n[true]` rule. It is corrected
  and tested against current compositor semantics. Named displays no longer
  replace address identity during geometry or placement confirmation.
- App default launches with temporary workspaces disabled already avoid the
  active-workspace read; that portion of the finding is rejected. Explicit
  current launches and portal placement now support named addresses.
- Named workspaces are published as ordinary read state with null numeric IDs.
  The numbered strip and version-1 temporary lifecycle remain numbered. Full
  named lifecycle creation/close/reservation is deliberately deferred because it
  needs a protocol/guard design, rather than weakening existing safety checks.
- Portal formatting is corrected. Local original-plan status and named-workspace
  assumptions were updated without tracking `docs/`.


### Commit map

| Review item | Repository and fix commits |
|---|---|
| 1 — read isolation | bar `eb314b7` |
| 3 — manual move cancellation | bar `24c38a9` |
| 2 — named identity, reads and routing | framework `c971521`, `8d4a773`; bar `8a252d4`; app `d8dc2ab`; Shelllist `9715eff3` |
| 4 — production capability scope | framework `3c72b4d` |
| 5 — client/cache reuse | app `62b78e9` |
| 6 — version suffixes | framework `e12047a` |
| 7 — formatting | Shelllist `9715eff3`; latch deduplication deliberately deferred |
| 8 — leftovers | legacy special-ID heuristics removed with named identity; urgency wire field retained |

### Final checks

All Nix development commands used `--no-write-lock-file`; no lock file changed.

- Framework: `cargo fmt --check`, warning-denied workspace/all-target clippy,
  full locked workspace tests pass. The Hyprland crate has 34 passing unit tests.
- Bar: formatting, warning-denied all-target clippy and all locked tests pass:
  330 library and 34 integration tests; eight opt-in tests remain ignored.
- App: formatting, warning-denied all-target clippy and all locked tests pass:
  67 library and 22 session tests, plus the subprocess helper; ten opt-in/helper
  entries remain ignored in their ordinary harnesses.
- Portal: formatting and five locked tests pass.
- Actual Qt WorkspaceStrip interaction: five checks pass, including a named
  active workspace with no synthetic numbered selection and a real pointer
  click. The test used Qt 6.11.1, matching import paths and the application's
  font configuration. Initial ad-hoc runs exposed missing Qt imports/fonts and
  a test click before layout settled; the final test waits for rendering.
- Private installed Hyprland 0.57.1 acceptance passes after the final identity
  guard change, covering named/special reads/events and numbered safety guards.
  Portal tests were also rerun after that change. The final full consumer suites
  preceded only that narrow parser/selector hardening; all affected framework
  tests and warning-denied framework clippy were rerun afterwards.
- Logs: `/tmp/{framework,bar,app,portal}-ipc-review-final.log`,
  `/tmp/{app,bar}-ipc-review-final-clippy.log`,
  `/tmp/framework-ipc-review-invalid-identity.log`,
  `/tmp/framework-ipc-review-final-guard-acceptance.log`, and
  `/tmp/shelllist-ipc-review-workspace-qt.log`.

No system rebuild, production service restart, production compositor restart,
push, hardware recovery check or real non-UTF-8-title experiment was performed.
The default bar strip and temporary lifecycle remain numbered. App launches from
named contexts with the temporary lifecycle enabled still require a future
versioned owner-context/reservation design; errors are not bypassed. These limits
are intentional deferrals, not claims of full named-lifecycle support.
