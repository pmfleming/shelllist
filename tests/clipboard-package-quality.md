# Clipboard package smoke: bounded quality review

Disposition: **partial unsupported-language evidence; coordinator review required**.
This completes the bounded manual/Python quality loop, not a Rust/QML Lens pass,
actual packaged-main acceptance, integration or rollout approval. The existing
[implementation record](clipboard-package-safety.md) remains historical evidence.

## Complete original-baseline inventory

No seeds. Original producer baseline `55bbbd506a4216d63963461bb06ef19661626ec4`;
frontend baseline `6f14ede26d27cff03b72e51f647ee5e96dba6928`. Clean BEFORE heads:
producer `a3879f0071dfc8c2ec2556ef0e13832b643dec46`, frontend
`13f349a5584c63db428d050b4adfd365e3c26c72`.

Reviewed all five baseline-to-implementation files, not only the latest commit:

| File | Review / applicability |
| --- | --- |
| clip-daemon/scripts/package-smoke.py | Complete rewrite versus original; package matching, CLI real-main gate, environment, private config, argv, bounds, process cleanup and unique-owner calls. Python unsupported by either Lens. |
| clip-daemon/test_support/package_smoke_service.py | Whole new inert fixture: explicit address/runtime validation, no domain imports/default bus, read-only synthetic result, lifetime, teardown and generated metadata only. Python unsupported. |
| clip-daemon/tests/test_package_smoke.py | Whole new suite: static/command construction and private real-bus lifecycle boundaries; no live backend. Python unsupported. |
| clip-daemon/contracts/package-smoke.md | Whole contract: scope, safe reproduction, synthetic versus real acceptance, retained coordinator gates. Markdown N/A. |
| shelllist/tests/clipboard-package-safety.md | Whole implementation evidence, historical failures/hashes and explicit incomplete acceptance. Markdown N/A. |

There are no changed Rust/QML/JS/TS/shell/Nix project inputs or generated companions.
This quality record is an additional scoped Markdown artifact. Full patches and
Git/content inventory are retained under the task's `quality/before/`; final
inventory includes the quality commit and this record too.

Pinned RQLens `d28f3d9` and QML Lens `97feb1f` README/evidence/testing policies were
read, and their CLI hashes checked against this run's provenance. Neither supports
Python, so the required Lens list is empty. No Lens run or extraction-helper build
is claimed; this is applicability, not an extraction pass. Producer rqlens.toml
and justfile include broad audit/live/capture/hardware/benchmark recipes; these
were inspected and deliberately not invoked. No applicable existing Python
linter/formatter configuration was found. The actual language-specific owners
are `py_compile`, stdlib `unittest`, and the explicit private native cases.
Task-local Bash driver syntax also passes `bash -n`.

## Introduced findings and justified changes

1. **Inherited INI defaults (static wiring false positive).** ConfigParser accepts
   `[DEFAULT]` entries as inherited `[Service]` values, unlike packaged systemd/
   D-Bus definitions. A private inert template with `ExecStart` moved out of
   `[Service]` was accepted at BEFORE. The shared INI boundary now rejects defaults
   explicitly; a complete static-inspection regression expects that rejection.
   This does not attempt to implement a general systemd parser/job graph.
2. **Child closes stdout but outlives the deadline (exception inconsistency).**
   Selector expiry already returned redacted `SmokeError`, but wait expiry after
   EOF escaped as raw `TimeoutExpired`. The BEFORE probe reproduced that path
   with an independently bounded Python child. Cleanup/time bounds already held;
   this was not an unbounded-child finding. The runner now normalizes wait expiry
   to the same deadline failure without exposing argv, still using its existing
   `finally` process-group cleanup. Extended the existing deadline/output owner.

Both issues were introduced in the new implementation helpers, not inherited
Rust/QML findings. No metrics, thresholds, exclusions, warning suppressions or
policy guards were changed. No mechanical splitting/new policy layer, unrelated
baseline cleanup or test deletion was justified. Existing local and native
cases protect distinct command-construction, boundary-failure and real-bus
ownership risks; mocks are not credited as covering the producer they replace.

## Comparable executable evidence

All checks are foreground, bounded, awaited through the shared lock. From this
family's `worktrees/`, with `PHASE` set to `before`, `after`, then `final`:

```sh
/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh timeout 900 \
  nix develop ./daemon-framework --no-update-lock-file --command \
  bash "$ORCHESTRATION_TASK_DIR/quality/run-checks.sh" "$PHASE"
```

The unchanged driver bootstraps the family's launcher in the frozen framework
shell, performs producer sibling-source preflight/capture, enters the matching
producer shell, records tools/Git/source hashes, syntax-compiles all three Python
files into task-private bytecode, executes the native-enabled suite, and runs the
same two inert regression probes. No installed/stale producer or source override.
A final clean-quality-head replay is recorded in the matching task report.

| Phase | Observations |
| --- | --- |
| BEFORE, clean implementation | Syntax + all 20 tests pass / zero skips. Review probes record invalid INI accepted and raw `TimeoutExpired`; these are recorded defects, not a clean static result. |
| AFTER, refactored source | Syntax + all 21 tests pass / zero skips. Same probes now record explicit rejection and `SmokeError`; both resolved. |

Artifacts:
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/04-clipboard-package/quality/`.
`before/check.log`, `before/probes.json`, `after/check.log`, `after/probes.json`,
`final/check.log`, `TRIAGE.md`, inventories and source-hash files retain exact
commands, identities and results. Probe JSON is explicitly manual regression
observation, **not** a Lens/static-semantic analyzer artifact.

Matching tools: Python 3.13.13, D-Bus 1.16.2, busctl/systemd 260.2, coreutils 9.11,
Cargo/Rust 1.95.0. Immutable executable paths/hashes are the same BEFORE/AFTER.
Busctl is selected from the existing shell PATH and used only with private bus
addresses; coordinator CI should declare that input. Tested AFTER source SHA256:

- smoke: `b10d32e82d0c8a02e92984557acce44177ba02229b4aa9a959f0b78871203202`
- tests: `3501b44c99703631ab25654734d23d5d9542c56ee27df17e59572163ee4a82c0`
- unchanged fixture: `5d2b483416083aba6787e7133be72406786767ba567aed6e6a689ee692ef41be`

## Retained limits / acceptance gates

Gio `register_object` deprecation remains a known current-library compatibility
warning, not suppressed to obtain a pass. No exhaustive Python semantic/type,
complexity or duplication extraction is claimed. No Qt/Rust/native producer
serializer/admission/backend pass is inferred from the synthetic service.

All original actual rendered package-output, real packaged-main/pinned-engine,
private policy/files/privacy, engine negotiation, startup/readiness/job graph,
upgrade/rollback and serial matched-release measurement gates remain not run.
Coordinator-owned Nix fileset/input/check wiring remains requested: current
package sources exclude scripts and current checks are Rust-only. No production
backend switch, unit/flake/lock/default change or startup strategy was added.
No Ringboard/capture worker, real clipboard/data/paste/publication, live bus/
compositor/manager/hardware, deployment or installation was exercised. Existing
D-Bus/retained clients, admitted services, domain policy and UI drafts are untouched.
