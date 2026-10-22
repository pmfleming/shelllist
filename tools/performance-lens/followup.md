# Performance review follow-up

This supplements README.md's original schema-1 and task-pairing description.

## Delivered diagnostics

- CPU triage includes write rate/coverage, plus a separate disk-write ranking so
  low-CPU writers remain visible. Process I/O is not physical device throughput.
- Thread CPU uses a zero baseline only for identities whose start tick is strictly
  later than the previous snapshot's CLOCK_BOOTTIME tick. Same-tick births are
  ambiguous and not assumed new. Already-existing missed tasks never contribute
  their lifetime CPU as interval CPU. Phase boundaries still break pairing.
- Reports count observed new identities by last observed name and show process
  CPU minus observed thread deltas as **unattributed thread CPU**. This includes
  exited work, read gaps and sampling skew; negative residuals are unavailable.
  Threads born and gone entirely between snapshots cannot be named or counted.
- `--include-cgroups` samples the exact cgroup v2 paths of selected processes
  (deduplicated by path), excluding the observer's group. `cpu.stat`,
  `memory.current`, `memory.stat`, `io.stat` and three PSI files are separate reads.
  These kernel totals include short-lived descendant work without enumerating
  current membership. Scope paths and directory identities are recorded. Missing
  controllers, resets, I/O device-set changes and cgroup replacement break rates.
  The process target's existing exit policy is unchanged: primary exit still stops
  capture. No new/replacement service is silently attached.
- `--include-threads --include-scheduler` adds per-task schedstat nanosecond CPU,
  scheduler run-queue wait and voluntary/involuntary context-switch counters.
  A second task-stat identity fence guards the extra reads. Scheduler-wait
  accounting disabled by the kernel is unavailable, not zero. Aggregates cover
  observed paired/newborn tasks, not all exited work, and are separate from
  tick-based process totals. Context switches are **not wakeups**.

Cgroup totals overlap process totals and potentially other selected cgroups;
never add them. Charged cgroup memory includes cache/kernel memory and is not RSS.
The optional diagnostics add collector work and should be separate from ordinary
before/after application captures. No scheduler tracing or kernel settings are
changed. A release 5-second app/bar diagnostic capture with all three flags
completed and regenerated its report; this was a smoke, not a baseline.

## Compact schema 2

New captures store metric/counter objects as `[descriptor_index, value]`, or
`[descriptor_index, null, unavailable_reason_index]`. The manifest's
`sample_schema.descriptors` stores units/sources once, and
`sample_schema.unavailable_reasons` stores repeated reasons once. This applies to
process, task, scheduler, cgroup and GPU metrics. Integer counters remain full
JSON u64 values. Dictionary sizes and encoded rows are bounded. Ordinary
summary/CSV/HTML exports retain expanded semantics.

The reader supports schema 1 and schema 2, expands one row at a time, validates
references and existing identity/interval contracts, and still rejects rehashed
truncation or invalid metrics. Cross-schema A/B comparisons are intentionally
incompatible. An unfinalized capture is not a valid report artifact: finalization
publishes the dictionary and hashes, including on controlled partial exits.

The collector already counted emitted bytes before this follow-up; no per-tick
metadata call remained to remove. Each complete compact row is budget-checked
before writing. Reports now show observed encoded byte rate and an extrapolated
capacity duration, explicitly not a guarantee for changing task/GPU workloads.

A representative release test row shrank **2252 → 836 bytes**; extrapolating
14,401 observations for eight process scopes gives **96,313,888 bytes**, below
128 MiB. This tests serialized capacity, not an actual one-hour run. Optional
thread/cgroup data or many GPU clients can still exhaust the cap earlier.

Three alternating 10-second passive release runs per side (bar + app + observer,
250 ms base / 1000 ms detail, 1 s settling, no concurrent builds):

| Metric | Original observer | Follow-up observer |
| --- | --- | --- |
| Observer % one core | 1.100, 1.000, 1.100 | 1.001, 1.000, 1.100 |
| Mean encoded row bytes | 2326.6, 2328.6, 2325.9 | 899.0, 897.2, 897.2 |

This is about **2.6× smaller**, not the suggested 5×. Observer CPU is comparable
at this run length/tick resolution; no collector speedup is claimed. The changed
observer and schema make these diagnostic measurements, not an application A/B
verdict. Local artifacts: `/tmp/shelllist-perf-rollout/observer-captures/` and
`diagnostic-captures/`. Existing incoming build-input and README edits were not
included in these implementation commits.

## Held procfs descriptor investigation

The owned-child regression verifies real `stat`, `status`, `io` descriptors and a
pidfd through exec-in-place and reaped exit. On this kernel all three held reads
returned ESRCH (errno 3) after exit. However, they remained readable after exec,
with unchanged PID/start ticks, and the pidfd was not signalled. The existing
executable identity fence correctly rejected the exec. A pidfd therefore cannot
replace the executable/UID checks. The test never kills an external process.

A release probe alternated 1,000 three-file reads with the same pre/post identity
fences, three times. Reopening: **45.969, 46.266, 45.908 ms**. Retained descriptors:
**37.313, 37.157, 37.092 ms**. This isolates file access, not the entire collector
or PSS/GPU costs; the probe also reads stat separately from the identity fences,
unlike the production collector's existing stat reuse.

Decision: retain production identity checks and do not add a retained-fd cache
for this roughly 9 microsecond/sample opportunity (~0.03% of one core for eight
processes at 4 Hz). It would add descriptor ownership, exec handling and teardown
complexity for a much smaller benefit than the deployed watcher and history
changes. A future design must budget at least four retained fds/process (three
files plus pidfd: 256 at the current 64-process limit), preserve identity across
exec/UID changes, and retain explicit errors on missing procfs files.

The framework's independent real-bus investigation is documented in
`daemon-framework/docs/proxy-performance.md`: fresh method-only proxies added no
match-rule round trips, and three paired release runs showed no consistent gain
from caching. No transport or payload-format change was justified. These two
investigations complete the conditional lower-priority work, rather than adding
unproven micro-optimisations.
