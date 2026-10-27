# Agenda / Calendar core release evidence

Scope: `contracts/agenda-ui.md` and `contracts/agenda-calendar.md`. Independent
`shelllist agenda` and `shelllist calendar` routes share one QML list/editor;
`activity` remains an Agenda route alias. Rust owns persistence, validation,
projection, membership, ordering and search. Weather/Notifications remain separate.
Recurrence, reminders, attachments, invitations and remote writes remain deferred.
Unsupported recurrence is visibly reported, not silently expanded or discarded.

## Ownership and reviewed checkpoints

Five concurrent workers used `openai-codex/gpt-6.1-sol`, high reasoning. Each
implementation was reviewed/committed before its actual quality-lens analysis,
refactor, verification and separate quality commit. Only the orchestrator committed.

| Ownership | Implementation | Quality refactor |
| --- | --- | --- |
| Private Turso storage (`bar-daemon`) | `32d8d91` | `7a96536` |
| Offline maintenance (`bar-daemon`) | `20dd2a2` | `68416a5` |
| Native domain/API (`bar-daemon`) | `8876a9f` | `52046cd` |
| Shared QML list/editor (`shelllist`) | `dd68cfa` | `e00cbf1` |
| Calendar/routes (`shelllist`) | `2337670` | `c6b665c` |

Additional reviewed checkpoints: producer/frontend bindings `db95740`/`3611ff3`,
failed-rollback read fencing `676ac29`, bounded source diagnostics `d2599d3`, and
actual feedback-width allocation `b8e1ec2`, and captured completion-intent revision
fencing `534c007`. Original planning commit `fd239ac` is
preserved. Initial worker commits and later correctness corrections are not
misrepresented as behavior-preserving refactors.

Raw reports, sessions, exact tool/config/source provenance and failed attempts are
retained at `/home/laufan/Projects/shelllist-orchestration/agenda-20261027/`:
`control/{storage,maintenance,domain,list,calendar}-{implementation,quality}.md`,
commit receipts, `logs/`, and each worktree's `target/agenda-*` evidence folders.

Actual tools: Rust Quality Lens 0.1.0 (SHA256
`622b2c793a574781cd40a190a457f58af4b8c222ee5efce04c4e77488c50929a`);
QML Quality Lens 0.5.0, repository `97feb1f`, evaluator fingerprint
`ecbe448644080d95c83fc67b09fdf409d983163a2b5166d7b7eeb2585c605655`.
Static findings/type gaps and incomplete verdicts remain disclosed in the reports;
no lens score is substituted for native tests. The list's unsupported initial glob
exclusion was rejected as a baseline; final owned measurements use 11 explicit
production files. Maintenance's unstable shared-tree attempts were rejected and
replaced by provenance-checked frozen syntax inputs.

## Native qualification

Backend frozen source: `bar-daemon` **`d2599d3`**. Canonical prepared graph:
`backend-qualified-v2/sources.json`. Actual optimized Nix package:

```
/nix/store/lyypq6cnflzzc20q9mz3w6h9nhfq1d2s-bar-daemon-0.1.0
```

- `cargo test --release --locked --offline --all-targets -- --include-ignored`:
  **318 passed (284 + 2 + 30 + 1 + 1), zero failed/ignored**.
- Actual optimized Turso 0.8.0/Syscall I/O post-check passed: full CRUD, large bounded
  payload, readonly restart, durable catalog/receipts, private logical export/restore.
- Packaged maintenance executable passed its private real-process smoke.
- Logs: `backend-package.log`, `backend-package-confirm.log`,
  `packaged-maintenance-smoke.log`.

Focused evidence additionally includes storage **24 debug + 24 release** tests,
maintenance **9 library + 2 CLI** tests, native domain **279 passed + 5 existing
manual probes ignored** before those probes were included in the package gate,
strict Clippy, shared editor **50 passed**, and calendar **12 passed**.

Final frontend runtime checkpoint: **`534c007`** plus the reviewed manual fixture
and lens configuration. Canonical `frontend-qualified-v3/sources.json` passes all
seven gates: **596 Qt tests passed, zero failed, one existing RHI-only skip**,
strict QML lint, surface catalog, actual generated surface CLI, native bar-daemon
contract, packaged imports and default application package. Exit0;
log `frontend-package-v3.log`. Qualified application:

```
/nix/store/8m2mzrxzvr1350q72x4p18mm38lc75vi-shelllist
```

All **786 tracked non-documentation files**, excluding the preparer's rewritten
flake files, byte-match the reviewed final source
(`control/final-frontend-source-provenance.json`). This evidence document is
finalized after the run; documentation-only differences are explicitly recorded.
No changing-tree test is substituted for these immutable package gates.

Producer fixtures regenerated from the packaged daemon byte-match all checked-in
contract/read/control/display/notification/battery fixtures and the native method
registry. The actual framework-built `shelllist-protocol-js` regenerates
`BarProtocol.generated.js` byte-identically. Evidence: `generated-final/`.
Sibling graph inputs are real registered, detached worktrees at clean current
heads, not symlink identity overrides or source-policy bypasses; exact dependency
heads are in `control/qualification-dependency-heads.txt`.

## Failures retained and corrected

- Untouched frontend baseline: **527 passed, zero failed, one existing skip**.
- Changing-tree diagnostic run: **554 passed, one failed, one skipped**. The invalid
  test-helper invocation was corrected; this run was never accepted as a release gate.
- First immutable frontend package: **588 passed, one failed, one skipped**.
  Actual sandbox fonts rendered `unsupported iCalendar recurrenc…`: a guessed
  half-pane budget used only 212.5 px despite a 371 px shared label allocation.
  Native FontInfo/actual text, a separate immutable diagnostic replay, and a private
  font-sysroot reproduction established the cause. `b8e1ec2` uses the real shared
  feedback text width for Agenda and Calendar, retaining the recurrence assertion,
  full accessible diagnostic/count, fixed footer height and resize assertions.
  Its actual seven-file supplemental lens reports the small advisory score cost
  honestly (77→76), with unchanged static findings; no typography shrink or waiver.
  `frontend-feedback-probe.log` retains the failed replay;
  `control/list-final-package-fix.md` records the correction.

- Final effect audit found that deferred Complete could toggle a newer fetched
  completion value instead of honoring the action's captured revision. Four actual
  bridge scenarios failed before `534c007`; all seven new scenarios then passed.
  Newer records remain inspectable, but changed actions produce no mutation and
  visibly require review. Cached and deferred exact-revision actions still work;
  only a new explicit intent can toggle the reviewed newer record. Focused editor
  suite: **57 passed**; calendar: **12 passed**; strict lint passes. Supplemental
  actual lens records the necessary guard complexity/score cost without claiming
  a refactor improvement. See `control/list-final-completion-fix.md` and
  `target/agenda-final-completion-guard-20261027/`.

Other review corrections cover immutable begin-edit revision/target and compound
baselines, actual transport-generation authority after lower-revision restore,
bounded recovery without mutation replay, retained accepted windows on gaps,
committed receipt reconciliation and failed-transaction read fencing.

## Native visual and interaction evidence

Real light/dark QML captures were reviewed, including populated inspectors, long
notes, source warnings, first-open calendar and measured `1.5W → W → hidden`
fallback with stable editor identity. Final captures live under
`target/agenda-quality-calendar/captures-final/`, the list's owned quality evidence,
and `target/agenda-final-feedback-fix-20261027/captures/{light,dark}/`.
The manual action-review fixture now seeds actual Agenda list/get replies and
asserts that captures do not send native mutations. No HTML screenshot is counted
as application evidence.

## Operational safety and acceptance limits

All checks use private HOME/XDG, disconnected D-Bus/Wayland, offscreen Qt and
synthetic temporary databases. No deployment, service restart, live Agenda or
Scratchpad access, or system clock/timezone changes were performed.

The daemon owns a dedicated private Turso store, never Scratchpad's database.
Legacy migration retains original bytes and a durable private backup; there are
no continuing dual JSON writes. Use explicit offline `agenda export` / `agenda
restore` following `bar-daemon/tests/agenda-maintenance.md`; restoring old JSON
alone loses post-migration edits. Imported calendars remain provider-owned.

Offscreen evidence does not certify live compositor placement/fractional scale,
hardware IME/touchpad behavior or human assistive technology. Actual EFBIG is
exercised; physical ENOSPC, power-cut and storage-device fault certification are
not claimed. Unsupported sub-minimum layouts report their limits rather than
adding horizontal panning. Neither package was deployed.
