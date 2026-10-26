# Completion-plan orchestration acceptance — 2026-10-26

Scope: launching Wave 1 of [the completion plan](../contracts/project-completion-plan.md),
not acceptance of unfinished worker implementations or rollout.

Run: `/home/laufan/Projects/shelllist-orchestration/20261026T202406Z`.
Planning commit: `6f14ede`. The manifest freezes all eight source heads at bootstrap;
this later documentation-only acceptance record does not change their source bases.

## Prepared and observed

- Six independent owners and 48 sibling-family worktrees; exact path allowlists,
  owned branches, detached dependencies and inherited seed mappings in the manifest.
- BT/framework seeds applied only to private worktrees. Their source remains
  unapproved until fresh checks, missing quality work and coordinator review.
- Live no-tools model preflight returned `READY` with authoritative assistant
  `openai-codex/gpt-6.1-sol` / `high` / `stop` and non-aborted settlement.
- All six actual worker streams independently verified Sol/high after launch.
  Environment identities and persisted session files are retained per task.
- Implementation supervisor PID at launch: `804310`; quality supervisor: `804637`.
  These are historical launch identities, not a promise those PIDs stay alive.
- Six-session combined cap; 90 minutes per checkpoint; shared cross-run heavy-check
  lock; bounded event logs/records; owned process-group cleanup and no implicit retry.
- Automatic quality continuation uses the exact exited implementation session,
  archives its original handoff and requires a distinct nonempty refactor/evidence
  commit. Neither supervisor performs semantic approval or project integration.

## Checks performed

`python3 -m py_compile` for the run's Python files and `bash -n check.sh` pass.
Through the private shared-lock wrapper, `python3 -m unittest -v test_quality
test_pipeline` initially passed **11 tests**:

- Lens applicability vs docs/unsupported languages; combined phase and conservative
  heartbeat projection; total slot reservation; surviving-group exclusion.
- Required private before/after evidence and preservation of partial acceptance.
- Dirty/unowned/forbidden-file scope failures, seeded input vs a fresh implementation
  commit, and rejection of absent or empty second quality commits.
- Offline fake-CLI end-to-end implementation/archive/exact-session continuation,
  wrong-model rejection before quality and missing-quality-commit rejection.

### Detached-tool correction

Subsequent observation and Pi source inspection demonstrated that Bash tools use
separate process groups; an exited Pi parent group alone was an incomplete departure
check. The still-unused quality observer was paused, while all six implementation
sessions continued unchanged. A bounded read-only Linux census now checks task
markers, task-local working directories and birth-identified observed descendants
(including reparenting) before quality can start. Quality completion also waits for
those processes. PID reuse does not inherit an old observed identity.

The expanded `test_quality test_pipeline test_process_guard` suite passes **15 tests**,
including a real detached private-child interlock, marker/cleared-environment cases,
reparenting/birth mismatch and unused-observer continuation without restarting workers.
These lightweight offline Python/Git/process fixtures ran with private HOME/TMPDIR
and unavailable buses, without occupying the heavy-build lock or executing a model,
compiler, native service or benchmark. `control/process-guard-tests.log` retains them.

The old observer state/logs are archived under `control/quality-observer-pauses/`.
Explicit `--continue-waiting-observer` accepts only an exited observer with no prepared
or launched quality phase; it cannot retry a worker. Continued observer launch PID:
`899495`. The first BT implementation finished normally during this maintenance;
its first authorized quality continuation then began after guarded departure.

This census does not terminate detached groups, observe Nix-daemon-owned builders,
or constitute an OS sandbox. A completely environment-cleared, reparented child
outside task directories that was never observed still depends on fixture cleanup.
Workers must await/reap all checks; integration must recheck process quiescence.
The initial parent-group-only evidence is retained, not rebranded as that guarantee.

The fake-CLI tests are **orchestration fixtures**, not actual model, Rust/QML Lens,
Qt, native daemon or performance passes. Python/shell orchestration is not covered
by either Lens. The separate real preflight and actual worker events establish model
identity. No project runtime suite was rerun merely for this Markdown plan/record.

Pinned Rust CLI/source, QML compiled-JS aggregate and dependency-lock hashes were
reverified against the prior run. No analyzer was rebuilt or installed by preparation.
Normal pinned locked extraction-helper compilation in each worker's private cache
is explicitly permitted; this is distinct from rebuilding/replacing analyzer sources
or CLI. The installed Pi 1.4.0 path changed since the earlier run; critical CLI/JSON/
session documentation was byte-compared with the read documentation and matched.
Actual runtime path/version is retained in `control/pi-runtime-identity.log`.

## Evidence and remaining gates

Run-local evidence: `control/orchestration-tests.log`, `control/tool-verification.log`,
`control/model-preflight.jsonl`, `control/bootstrap.log`, `manifest.json`,
`control/{state,quality-state,dashboard}.json` and each task's identity/event logs.
Snapshot/status records are observations, not completion claims.

Worker code, native/Qt/contracts/Nix results, BEFORE/AFTER analysis, scope and both
commit stages still require coordinator review before integration. Successor waves
must use accepted refreshed source tuples. Startup strategy and rollout remain
explicit decisions; bridge default, services, deployment and live effects unchanged.
The existing `/etc/nixos` dashboard work is dirty and outside these worker families;
no changes there were staged, overwritten or committed by this orchestration.
