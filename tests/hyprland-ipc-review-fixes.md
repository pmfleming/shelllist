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

Pending implementation. Each closure below will identify checks and commits.

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
