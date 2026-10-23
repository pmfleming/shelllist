# Performance review: deployed resources and internal lens

Review source: Shelllist `bac786d`; related app-daemon source inspected at
`5f29dcc`. These are **not deployment identities**. The internal Rust lens at
`tools/performance-lens/` measured the existing same-user Quickshell process and
already-running daemons. No panel control, setting changes, service restarts,
deployment, sibling edits or state-file reads were performed. Only the history
file's size/mtime was inspected. The incoming `bar-reads.json` edit is unchanged.

## Evidence and conditions

Raw manifests, hashes, samples, offline HTML/CSV/JSON, pre/post read-only IPC
checks and test/probe logs are under `target/performance-review-current/` (ignored).
All five captures completed; no builds ran during collection. The live desktop
was **not exclusive**: display, power, other clients and user activity were not
controlled. These are diagnostic observations, not matched A/B acceptance.

| Capture | Run ID | Protocol |
| --- | --- | --- |
| Baseline 1 | `1792753219894-605434-0` | 3 s settle, 20 s capture, 1000/5000 ms base/detail; UI, service members, five daemon services, observer |
| Baseline 2 | `1792753243084-605543-0` | Same protocol |
| Baseline 3 | `1792753266278-605594-0` | Same protocol |
| Task diagnostic | `1792753298250-605643-0` | 3 s settle, 20 s capture, 500/5000 ms; UI/app/bar/observer, threads, scheduler and cgroups |
| Persistence diagnostic | `1792753642631-628781-0` | 3 s settle, 150 s capture, 1000/5000 ms; UI/app/bar/observer only |

At initial read-only preflight, the popover was hidden and six surfaces had been
opened previously: Battery, Bluetooth, Clipboard, Media, Updates and Wi-Fi.
Visibility was not continuously sampled. At the final check, Notifications had
also been opened and was **visible**. The longer run therefore cannot be labelled
an idle baseline. No attempt was made to close it or interfere with the user.

The manifest records immutable deployed QML:
`/nix/store/j1myrghjjifvr269bzd47kpx5flg07d0-shelllist-config-0.2.0/share/shelllist/shell/shell.qml`,
and the actual Quickshell/app/bar executable paths and SHA-256 hashes. Do not
substitute checkout HEAD for those fingerprints. Different diagnostic protocols
and the rebuilt observer are not an application before/after comparison.

## Resource observations

CPU is percent of **one core**, weighted by valid intervals, not total-machine
percent. The first three captures had approximately 19 s UI coverage and 20 s
coverage for the other processes; settling is excluded.

| Scope | CPU across three captures | Sampled peak RSS range | Sampled peak PSS range |
| --- | --- | --- | --- |
| Quickshell UI | 0.211%, 0.105%, 0.053% | 421.3–422.7 MiB | ~359.0 MiB |
| app-daemon | 2.450%, 2.300%, 3.150% | 51.27–51.30 MiB | 48.96–48.99 MiB |
| bar-daemon | 1.800%, 1.800%, 1.850% | 58.74–58.76 MiB | 51.74–51.75 MiB |
| Lens observer | 0.550%, 0.600%, 0.550% | 4.63–4.80 MiB | 2.85–3.02 MiB |

Other daemon CPU was 0.15–0.40%; bridge clients were 0–0.10%. Sampled zero CPU
means no observed tick delta, not no work. RSS/PSS/cgroup totals are not additive.
The previous review's ~97%-of-one-core bar watcher saturation was **not observed**
in these captures; the old and current deployments/protocols differ, so this is
not a controlled speedup claim.

## Prioritized findings

### 1. App history persistence rewrites substantial data — strongest candidate

**Observed:** the task diagnostic recorded 63,320,064 storage-accounted write
bytes (60.4 MiB). The longer run recorded another **126,382,080 bytes (120.5 MiB)**,
in two roughly 60 MiB bursts ending at elapsed 36.0 and 98.0 seconds. App CPU
peaked at 53.49% over a roughly one-second sampling interval. Syscall character
writes were similarly large; the history file's final size was **63,173,919 bytes**.
This is consistent with history persistence, not proof of write call stacks,
physical-device traffic, fsync latency, wear or an extrapolated daily workload.

**Source:** app-daemon `service.rs::track_resources` checks a 60-second save
interval. `HistoryStore::snapshot` and `history.rs::persist_snapshot` still write
the complete retained resource/energy history atomically. Current source already
has compact JSON, dirty generations, shared snapshot points and blocking-writer
offload; do not propose those existing optimizations as new fixes or assume their
exact deployment from source inspection alone.

**Next:** measure an isolated full-retention fixture, then compare per-application
or time-chunk dirty persistence against full snapshots. Preserve atomic replacement,
private permissions, final-save/shutdown behavior, serialized writer ownership,
failed-write retries, retention repair and cursor epochs. No storage-format change
is justified without migration/recovery tests and repeated deployed measurements.
Simply skipping final saves or weakening durability is not an acceptable shortcut.

### 2. Background application sampling remains recurring work

**Observed:** app-daemon was the busiest service in all three short captures. In
the longer run it averaged 3.13% of a core; CPU bursts recur about every ten seconds,
including between the two large writes. The task diagnostic localized its observed
CPU to one `tokio-rt-worker`, not a function. Character reads averaged about
55 KiB/s in the long run, with no storage-accounted reads. Cached procfs/file reads
are not free merely because physical read bytes are zero.

**Source:** app-daemon `service.rs::ResourceSamplingPolicy` uses 10-second
background and 2-second demanded sampling. `resources.rs` already separates
10-second memory and 30-second open-file refreshes and caches process data.

**Next:** profile discovery, memory/DRM collection, attribution and history
aggregation separately with controlled process/application counts before reducing
cadence or adding caches. Preserve PID/start-time ownership, resume/reset fences,
missing-data semantics and demand transitions. CPU recurrence and source cadence
support this investigation, but do not establish which stage is expensive.

### 3. Warm-panel retention and first activation need a controlled UI journey

**Observed:** the pre-warmed UI retained roughly 422 MiB RSS / 359 MiB PSS with
very low sampled CPU. During the longer, nonexclusive run, RSS rose from 422.1 to
487.7 MiB, peaking at 491.2 MiB; sampled peak PSS was 393.8 MiB. Several late CPU
windows reached 43–100% of a core. Notifications was newly opened and visible by
the final check. **This is not evidence of an idle regression, a leak, or a measured
notification-open latency.** There is no per-action timing or allocation stack.

**Source:** `shell/SurfaceRegistry.qml` retains opened/loaded identities;
`shell/SurfaceSlot.qml` retains loaded bundles; `shell/ShellContent.qml` keeps a
content Loader active after its surface has been opened. This intentionally trades
memory for warm reuse. Notification list/timeline reads are paged and active-gated;
do not claim the entire native history is eagerly rendered.

**Next:** in an explicitly consenting exclusive session, measure cold activation,
repeated open/close, all-surfaces warmed and long-hidden retention. Separate GPU
resources, QML objects and domain data. Consider releasing only hidden view trees
if memory is demonstrably recoverable; retain controllers, pending operations,
selection/viewport state and shared save/discard/focus behavior. Reinstantiation
cost and native keyboard regression tests are required before changing lifetime.

### 4. Diagnostics can cost as much as the work being investigated

**Observed:** lightweight all-service observer CPU was 0.55–0.60%; adding task,
scheduler and cgroup diagnostics at 500 ms cost **2.00% of a core**, versus bar's
2.20% in that same diagnostic. The later four-process lightweight observer cost
0.42%; different scopes/cadence make that **not an observer speedup comparison**.
Some cgroup I/O and scheduler fields were unavailable. Unattributed thread CPU
had shorter coverage than process CPU; do not sum partial thread means or treat
unsupported pressure metrics as zero.

**Next:** keep expensive task diagnostics short and targeted. Use lightweight
captures spanning multiple save cycles for resource baselines. The improved report
separates overlapping scope rankings and exposes per-metric coverage, making
observer pollution and missing data easier to distinguish from application work.

## Controlled operation probes: useful, but not UI latency

The existing release search probes ran serially three times after compilation,
with no concurrent agent builds. Each performs 25 rankings over 1,000 synthetic
catalog rows; construction/preparation is outside the prepared-query timer.

| Path | Three runs, ms per 25 rankings | Median |
| --- | --- | ---: |
| Prepared catalog | 84.462, 87.832, 78.642 | 84.462 ms |
| One-shot compatibility API | 129.302, 126.801, 127.948 | 127.948 ms |

Prepared median cost is about **3.38 ms/query** in this fixture. The ~34% difference
is descriptive amortized preparation cost, not a new optimization, statistically
certified effect or input-to-visible improvement. No comparison with old machines,
old runs or native UI rendering is implied. Larger catalogs and query mix still
need explicit experiments; preserve Unicode, tie ordering and request coalescing.

`tests/run-performance-benchmarks.sh` also produced a Node/V8 policy-model probe:
median-throughput inverses were 4.67 ms to normalize 1,000 rows, 0.014 ms for an
empty ranking and 1.69 ms for the filter fixture. Despite the legacy `qmlbench`
output naming and `qt6` metadata, **this is not a Qt/QV4 or frame benchmark**.
Neither probe is imported into the lens as responsiveness evidence. Search is a
lower-priority candidate than the demonstrated writes until actual interaction
profiling says otherwise.

## Internal lens improvements delivered

- `summary.json.rates` now exports every existing process/scheduler/PSI rate with
  metric, scope, phase, unit/source, time-weighted average, sampled peak, valid
  interval count, covered seconds and unavailable-observation count. Missing
  observations are never zero-filled. Unit/source changes remain separate.
- HTML now exposes storage/character traffic and page-fault rates, including peaks.
  Scheduler and pressure tables use that same projection and show all-unavailable
  metrics rather than silently omitting them. A peak is an interval average, not
  an instantaneous maximum. No task-wait sum is relabelled as latency or wakeups.
- Application CPU/write rankings exclude the observer and overlapping cgroups;
  full resource sections retain both. A cgroup and its process no longer compete
  as if they were independent application consumers.
- No collection code, cadence, IPC consent, identity fencing, raw schema, artifact
  hashes or comparison guards changed. This is reporting improvement, not an
  application speedup. Existing schema-1/2 artifacts regenerate with the new
  projection; old summaries without `rates` still deserialize. Rate summaries
  are not new comparison/regression budgets.

The review's first four captures were regenerated with the improved report; the
150-second capture used the rebuilt lens. Baseline sampler identities remain in
those manifests. Raw artifacts and original deployment evidence were preserved.

## Validation and reproduction

- Lens: **41 unit + 11 CLI tests pass** in both debug and release; three existing
  opt-in tests remain ignored. Added coverage: weighted unequal intervals, valid
  zero versus unknown, absent rates, scope/phase/provenance separation, escaped
  output, old summaries, overlapping-scope exclusions, and real capture/offline
  rate-summary equivalence. Existing corruption/identity/consent tests still pass.
- Release build, strict all-target release Clippy and formatting pass.
- Search: six ordinary tests pass; both existing opt-in probes ran three times.
- Node policy benchmark completed. All five real captures regenerated offline.
- No production QML changed; Qt interaction/full package/hardware/compositor
  performance and accessibility acceptance were not run or claimed.

```sh
cargo build --release --locked --manifest-path tools/performance-lens/Cargo.toml
cargo test --release --locked --manifest-path tools/performance-lens/Cargo.toml
cargo clippy --release --locked --manifest-path tools/performance-lens/Cargo.toml --all-targets -- -D warnings
quickshell list --all --json  # identify the existing PID, never reuse this review's PID blindly
LENS=tools/performance-lens/target/release/shelllist-perf
"$LENS" doctor --pid "$PID" --ipc-check
"$LENS" capture --pid "$PID" --include-service-members --include-related-daemons \
  --duration 20s --settle 3s --interval-ms 1000 --detail-ms 5000 \
  --context 'record actual conditions, visibility and workload; disclose anything uncontrolled'
# Repeat independently; for periodic persistence use >=150 s with targeted scopes.
"$LENS" report --run /path/to/run
cargo test --release --locked --manifest-path rust/shelllist-search/Cargo.toml \
  profile_ -- --ignored --nocapture --test-threads=1
tests/run-performance-benchmarks.sh target/performance/model-probe.json
```

Remaining evidence gaps: end-to-end search/input-to-visible latency, compositor
presentation/frame pacing, cold-start and post-close retention, stack/allocation
profiling and repeated controlled deployment A/B. The lens's consent-gated
warm-open scenario measures only its documented acknowledgement/Qt callback
endpoints; run it separately with explicit permission and no unsaved drafts.
