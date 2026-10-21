# Lens effectiveness review after the five improvements

## Verdict

The lens was useful for **deployment-aware resource triage**, not for proving all
five optimizations. It found the dominant live CPU consumer, measured its own
observer cost, retained missing data and avoided interfering with the desktop.
The operation speedups came from separate Rust probes and correctness tests.
The live application/daemon builds were not replaced, so those speedups are not
post-deployment acceptance results.

See [the original findings](../../docs/performance-review.md) for implementation
commits, benchmark workloads, timings and boundaries. This review changes only
the external lens and its documentation/tests, not the application or daemons.

| Improvement | What the lens established | What it did not establish | Follow-up |
| --- | --- | --- | --- |
| Updates watcher scope | bar-daemon consumed about 97% of one core while UI CPU was near zero | Which thread/function was busy; whether the fix reduced deployed CPU | Optional task CPU localization, including churning/unpaired tasks; daemon-role comparison |
| Skip impossible typo comparisons | A passive baseline and deployed identities | Scorer cost, semantic equivalence or query latency; the hidden session did not exercise this workload | Report explicitly separates resource capture from operation evidence; retain frozen-reference tests and controlled Rust probes |
| Prepare catalogs once | Memory/CPU counters of the deployed processes | Amortized preparation cost, search throughput or the new cache's memory tradeoff | Keep these as separate workload experiments, not inferred gains from an idle capture |
| Lazy history search text | Related-daemon resource scope | Cost of default/date/text page projection or preserved cursor/fingerprint behavior | Compare intentionally rebuilt daemon roles; retain the native page probe and domain regressions |
| Reduce lens procfs overhead | Observer CPU, sampled collection cost and overhead warning | Same-observer application A/B when the lens itself changes; isolated light-collector timings were external probes | Explicit conditional observer-change comparison and observer deltas, without relaxing protocol/context checks |

## Implemented changes

### 1. Optional task-level CPU localization

`capture --include-threads` samples `/proc/PID/task/TID/stat` at the main interval.
PSS/GPU retain their separate expensive detail interval. Default captures do not
enumerate task directories. Each task carries TID, start ticks, last name, raw
user+system ticks, its own monotonic timestamp, interval and null-with-reason rate.

Both process identity and phase generation remain fenced. Rates do not bridge
TID reuse, missing observations, resets or phase transitions. Enumeration is
bounded to 1024 tasks per process; exceeding the limit yields an explicit error
rather than a selected subset. Individual task read/exit failures remain visible.

HTML/JSON expose valid-interval CPU and coverage **and** unpaired task identities
with lifetime CPU counters. Names are never used as identities or merged. Task
percentages may cover disjoint times and must not be summed. Lifetime ticks are
not capture CPU. No stack traces, privileged profiling or automatic root-cause
claims were added.

**A useful validation failure:** the first prototype sampled tasks at detail
cadence. In live run `1792623714821-493160-0`, bar-daemon still used 97.12% of a core,
but its busy watcher tasks were replaced between 2–3-second snapshots, so their
rates were unavailable. Showing only paired task rates hid the important evidence.
This caused the cadence decoupling and explicit unpaired-task reporting, rather
than treating those missing rates as idle CPU. The manifest records task cadence
and comparison rejects a cadence mismatch even with a changed-observer declaration.

The revised passive diagnostic, `1792623941539-495173-0`, used 500 ms base sampling,
5000 ms PSS/GPU, one-second settling and ten seconds of capture, scoped to the UI,
explicit `bar` process and lens. It recorded:

- bar-daemon: **96.80% of one core** over approximately ten covered seconds.
- Six separate `notify-rs inoti` identities with valid task rates of roughly
  **96–100% of one core**, each over its own 0.49–1.50-second interval. These were
  successive tasks, **not six simultaneously saturated cores**.
- One task/phase entry without a valid CPU interval, retained as unavailable.
- Observer: **0.90% of one core**. This is a short uncontrolled, three-scope
  diagnostic, not an overhead certification or an A/B comparison with the earlier
  all-scopes runs. No builds ran during sampling.

This directly reproduces the thread localization that previously required another
tool. It still does not identify the watcher call stack or prove the deployed fix.

### 2. Compare the scopes actually being optimized

Comparisons now report CPU, sampled RSS/PSS and observed storage I/O for all
**uniquely paired roles**, including daemons and `lens-observer`, with CPU/I/O
covered seconds and complete resource coverage. Auto-discovered PID suffixes do
not become identities across runs. Ambiguous multi-member roles are explicitly
unpaired, never arbitrarily matched or summed. Stable custom labels remain literal;
reserved automatic/observer labels cannot be impersonated by `--related-pid`.

`--changed-scope related:bar-daemon` (or `bar` for an explicit custom label) permits
that intended executable change. Flags are repeatable and exact, without wildcards.
Unchanged roles still require matching executable fingerprints. Unknown roles,
membership changes, incomplete runs, different context/protocol/tick frequency or
missing deployed config identity still prevent deltas.

`--changed-scope lens-observer` also permits a different observer hash, but an actual
change marks the report **conditional_descriptive_only**, with an explicit observer
confound warning. Lens version/schema and protocol still must match; collector
equivalence is not verified. This is useful for reviewing observer cost, not for
claiming an isolated application A/B result. Default strict hash matching remains.

Comparison HTML now has readable scoped delta/coverage tables and prominent
compatibility warnings, with full JSON/provenance retained. It shows executable
and QML identities, and warns when no deployed target build change is observed.
A source checkout commit is never substituted for deployment identity.

### 3. Make the evidence boundary visible

Reports lead with CPU triage and evidence limits in HTML and `summary.json`:
passive captures have no responsiveness trials; search/history/watcher operation
benchmarks were not measured; thread CPU is not function-level causal proof;
related daemons may serve other clients; deployment is distinct from source edits.

Raw hashes, offline reports, schema-1 compatibility, missing values, existing
warm-open consent/ownership rules and the <1%-of-one-core provisional observer
warning remain. Task data stays in JSON rather than being misrepresented as
process CSV totals. Added fields are optional for older artifacts.

## Validation and remaining work

37 normal tests pass in both debug and release (27 unit + 10 CLI integration),
along with strict all-target Clippy, formatting and the release build. The collector performance probe is an
explicit opt-in; the ignored synthetic child entry point runs only under its
bounded owning integration tests.

- Real bounded Rust children cover named hot tasks and repeated task replacement
  between slow detail samples, passive capture and report regeneration.
- Regression coverage includes task identity/reset/gap/phase rules, enumeration
  limits, malformed rehashed task intervals, weighted summaries, unpaired lifetime
  counters, HTML escaping and old artifacts without task fields. The raw sample
  byte budget is checked before each complete encoded row, so large task snapshots
  cannot exhaust a batch reserve and leave an oversized/partial JSONL artifact.
- Comparison tests cover daemon PID/build changes, observer changes, conditional
  status, ambiguous roles, coverage/unknowns, reserved labels, and refusal to bypass
  context/protocol/completeness/membership/version/config/tick checks.
- Existing IPC safety, target-loss, interruption, raw-integrity and GPU tests remain.
- The default light collector probe remained approximately 48 ms per 1,000
  collections in release (48.156, 48.510, 46.941 ms; median 48.156 ms versus the
  previous implementation median 49.066 ms). This is a descriptive sanity check,
  not a statistical equivalence or whole-observer cost claim.
- Live validation remained passive. No panel control, service restart, deployment,
  hardware mutation or production code change occurred. Old raw captures and the
  new diagnostic both regenerated successfully. A second matched-protocol diagnostic
  (`1792624357681-497646-0`) used a later lens build: strict comparison rejected it;
  explicit `--changed-scope lens-observer` produced conditional deltas for UI, bar
  and observer, with both observer-confound and unchanged-deployment warnings.
  Local reports: `runs/review-strict-comparison/` and
  `runs/review-conditional-comparison/`. These validate the comparison workflow,
  not application performance or deployment acceptance.

**Still deferred:** structured operation-benchmark ingestion, a repeated alternating
A/B experiment coordinator, automatic workload/fixture provenance, dynamic cgroup
accounting, scheduler/stack profiling, search/input-to-visible timing, statistical
significance and regression budgets. In particular, the lens cannot yet replace
the Rust scorer/page-projection probes or certify their UI impact. These gaps are
now stated rather than filled with inferred measurements. Next acceptance should
use controlled deployment and repeat matched captures with the same observer.
