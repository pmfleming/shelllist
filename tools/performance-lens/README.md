# Shelllist performance lens

See [the performance follow-up](followup.md) for current thread accounting,
cgroup/scheduler options, compact schema 2, and validation results. It supersedes
the original task-pairing and raw-format descriptions below.

A standalone **Rust** Linux CLI for the real Shelllist process. It lives here but
is not a Shelllist library, runtime feature, Cargo workspace member, or production
build dependency. No JavaScript, Python, web server, application instrumentation,
root privileges, or sibling repository is required.

## Implemented

- `doctor`: same-user process identity and procfs/DRM capabilities; optional
  **read-only**, PID-targeted Shelllist IPC check.
- `capture`: passive CPU, memory, I/O, faults, thread counts, and supported DRM GPU
  counters. Optional explicitly identified related processes/service members and
  bounded per-thread CPU localization (`--include-threads`).
- `run warm-open`: opt-in open/hide trials, direct IPC acknowledgement and existing
  Qt frame-swap callback timing; warmup separated from measured trials.
- `report`: validate raw artifact hashes/contracts and regenerate static offline
  HTML, inline SVG timelines, CSV and JSON summaries.
- `compare`: context-matched **descriptive** deltas for uniquely paired process
  roles, including daemons and the observer. Explicit `--changed-scope` declarations
  permit intended executable changes without bypassing protocol/context checks.
  Incompatible runs get a report and nonzero exit; no invented performance budgets.

This implements the usable first version of [the plan](plan.html), not every
future scenario. Cold-session launching, automated retention scenarios,
search/input-to-visible capture, vendor-specific GPU tools, live dashboards,
continuous cgroup accounting, hard regression gates and significance testing
remain out of scope. Existing Shelllist benchmarks are unchanged.

## Build and test

The product dependency audit records this exact standalone crate in
`contracts/build-inputs.json` under `independentCrates`. Its own lockfile and
requirements are intentionally separate from production dependency alignment;
production path dependencies on it remain forbidden. This does not exempt new
nested crates from inventory checks or run the tool's tests during a rebuild.

From the Shelllist root, using its Rust development environment:

```sh
cargo build --release --locked --manifest-path tools/performance-lens/Cargo.toml
cargo test --locked --manifest-path tools/performance-lens/Cargo.toml
cargo clippy --locked --manifest-path tools/performance-lens/Cargo.toml --all-targets -- -D warnings
cargo fmt --manifest-path tools/performance-lens/Cargo.toml --check
```

The default binary is `tools/performance-lens/target/release/shelllist-perf`.
If `CARGO_TARGET_DIR` overrides this, use Cargo's emitted executable path. Build
before measuring; do not benchmark while compiling. Linux, readable procfs, and
same-user process ownership are required. IPC scenarios additionally require
Quickshell with `list --all --json` and `ipc --pid` support. Tests use Rust load
children, fake IPC endpoints, and coreutils (`sleep`, `head`, `printf`) for bounded
helper tests; they never operate the desktop or user services.

## Quick start: passive capture

Identify the **existing** instance. Listing instances does not start Shelllist:

```sh
quickshell list --all --json
LENS=tools/performance-lens/target/release/shelllist-perf
PID=12345 # replace with the actual Quickshell PID

"$LENS" doctor --pid "$PID"
# Optional: verify that this is the Shelllist endpoint, without opening anything.
"$LENS" doctor --pid "$PID" --ipc-check

"$LENS" capture --pid "$PID" --duration 60s --settle 10s \
  --context 'popover hidden; 2560x1440@120Hz; scale 1; default motion; Vulkan; AC balanced; quiet desktop'
```

Use your **actual** conditions, not the example values. Passive capture never
sends IPC, changes visibility, starts services, or alters the desktop. The PID
can be any explicit same-user process; passive mode does not assert that it is
Shelllist. A hidden popover still leaves the bar rendering. Visibility and
workload are operator declarations, not automatically detected state.

CPU/RSS/I/O are sampled every 250 ms by default; PSS and GPU collection approximately
every second (or slower if the configured base cadence is slower). Duration accepts
seconds or milliseconds (`60s`, `250ms`, `2.5`). Use `--interval-ms 1000` for a
lower-rate capture, and `--detail-ms 5000` to reduce expensive PSS/GPU reads
independently. The detail interval defaults to 1000 ms and accepts 1000–60000 ms. Captures too short to contain a valid CPU interval fail instead
of generating an apparently complete baseline.

Each command prints its unique run directory and report path. Defaults are
relative to the source tool directory embedded at build time, **not** the current
working directory. Use `--output-dir /absolute/path/to/runs` when moving/installing
the executable. Run directories have mode 0700, files mode 0600, are git-ignored,
and are never automatically pruned or overwritten.

### Process scopes

```sh
"$LENS" capture --pid "$PID" --include-service-members --include-related-daemons
"$LENS" capture --pid "$PID" --related-pid app=23456 --related-pid bar=34567
```

- `ui-host` includes the Quickshell process and all its threads, including the bar.
- `--include-service-members` requires the host to be in the exact
  `shelllist.service` cgroup; it lists its current descendant members.
- `--include-related-daemons` asks `systemctl --user show` for already-running
  `app-daemon`, `nm-daemon`, `bt-daemon`, `clip-daemon` and `bar-daemon` service
  cgroups. Absent services become warnings; nothing is activated. Other unit names
  can be handled using explicit `--related-pid LABEL=PID` arguments.
- Membership is a **start-of-run snapshot**, not dynamic cgroup accounting. New
  and short-lived processes may be missed. Existing tracked identities are checked
  throughout; replacements are not silently attached. Primary exit stops the run;
  other tracked-process loss makes the result partial.
- `lens-observer` measures the lens itself, not short-lived IPC helper CPU.
  Daemon activity may serve other clients, so it is not exclusively attributable
  to Shelllist. No process-group RSS total is presented as unique physical memory.

PID + start ticks, UID, executable path/hash and boot ID establish identity.
No command-line substring search, `--newest`, `pkill`, or application/service kill
is used. The only processes forcibly terminated are lens-owned helper groups on
helper timeout/output-limit failures.

### Optional thread localization

The [effectiveness review](review.md) found that process CPU localized the busy
bar-daemon but could not identify its watcher thread. Use a **separate diagnostic**
capture, not an unannounced change to your baseline protocol:

```sh
"$LENS" capture --pid "$PID" --related-pid bar=34567 --include-threads \
  --duration 15s --settle 1s --interval-ms 500 --detail-ms 5000 \
  --context 'actual diagnostic conditions; thread sampling enabled'
```

Tasks are sampled at the **main** interval, independently of costly PSS/GPU detail
sampling. This matters for churning watcher threads that may disappear between
slow detail samples. `--include-threads` is off by default; no task directories are
read by ordinary captures. Limit diagnostics to relevant processes and inspect
observer cost. The existing process identity fences remain, including a final
check after task reads.

Rates require the same TID **and start ticks**, consecutive observations and the
same phase generation. Missing/exited/reset/reused tasks never receive invented
zero rates. Reports show covered seconds, the last observed name, and tasks that
lack a valid rate, retaining their maximum observed **lifetime CPU ticks**. Those
lifetime counters are not capture CPU or latency. Names may repeat/change; task
percentages can cover different times and must not be summed or added to process
CPU. This is not stack profiling, complete scheduler accounting or causal proof.

Enumeration is bounded to 1024 tasks per process per sample. Exceeding that limit
produces an explicit unavailable snapshot rather than a biased partial ranking;
individual task read/exit errors are recorded with the unavailable-task count.
Tasks born and gone between samples remain invisible. Thread data and cadence
are recorded in raw JSON/manifest; full thread summaries stay in JSON, while HTML
shows the top 20 valid and top 20 unpaired entries outside initial settling.

## Responsiveness: explicit consent

Close any open panel and deal with unsaved drafts **yourself** first. Use a
session you can leave alone for the duration:

```sh
"$LENS" run warm-open --pid "$PID" --surface applications --trials 30 \
  --allow-ui-control --exclusive-session \
  --context 'same display/backend/power/workload conditions as the baseline'
```

The two consent flags are intentional:

1. This opens and hides a real panel and may steal focus.
2. Existing IPC has no atomic ownership lease, unique request ID, or way to detect
   someone editing the **same** panel. `--exclusive-session` is a promise not to
   interact during the run, not an isolation mechanism. Do not run against an
   actively used desktop. Cross-panel/visibility/request changes abort the run.

The lens only calls `ping`, `status`, `listSurfaces`, `responsiveness`, `open` and
`hide`, through `quickshell ipc --pid`. It does not call the `shelllist` wrapper,
whose startup behavior can replace stale hosts. It never changes Wi-Fi settings,
pairs devices, adjusts volume, dismisses notifications, previews displays, or
executes power/update actions. Opening a panel can still cause its normal data
refresh or radio discovery.

One warmup open is recorded but excluded from distributions. Subsequent opens
require fresh matching timing records; all attempts/outcomes are saved. A
failure stops the sequence rather than retrying silently. Cleanup hides only a
matching observed request. If ownership cannot be established, the panel is
**left open** with a diagnostic; close it manually. No focus-restoration promise
is made. Ctrl-C finalizes partial evidence and attempts this same bounded cleanup.

### Exactly what the timings mean

| Measurement | Scope |
|---|---|
| `ack_ms` | Rust monotonic time before spawning direct Quickshell IPC through valid command reply/process exit; includes helper cost. Not public `shelllist` wrapper latency. |
| `qt_frame_callback_ms` | Existing QML wall-clock milliseconds from `showPopover()` to its first `onFrameSwapped` callback. Not compositor presentation, fully loaded results, animation FPS or input-to-photon. |
| Content record | QML Loader completion on first open. Warm content explicitly records zero as **already loaded**, not zero render latency; it is never aggregated as latency. |
| Search/catalog timing | Not imported as current-action evidence: these existing fields lack query/freshness identity. |

Before/after trace records, command timestamps, poll observations, timeout limits
and failures remain in `events.jsonl`. Wall time is not subtracted from monotonic
clock values. Clock jumps greater than 20 ms invalidate a trial; smaller slews and
millisecond quantization remain limitations. First-frame and content endpoints
must both be fresh; already-visible surface switches cannot pass as new opens.
The current contract does not establish backend result readiness.

Protocol defaults live in `scenarios.toml`; the checked-in defaults are embedded
in the executable. Pass `--config path/to/scenarios.toml` to use edited defaults
without rebuilding. Unknown fields and out-of-range values fail. These values
are **not budgets**. IPC polling adds target work: use separate passive runs for
quiet resource baselines.

## Reports, comparisons and integrity

```sh
"$LENS" report --run tools/performance-lens/runs/RUN_ID
"$LENS" compare --baseline tools/performance-lens/runs/BASELINE_ID \
  --candidate tools/performance-lens/runs/CANDIDATE_ID \
  --output tools/performance-lens/runs/comparison-01
```

Open `report.html` directly in a browser. It contains no scripts or external
assets. Reports lead with CPU triage and explicit evidence limits, then cover
responsiveness, CPU, optional thread localization, memory, I/O, GPU and coverage;
all process scopes and phases stay separate. Plots show sampled points (at most
roughly 1,000 per series), not interpolated missing intervals. Hover/interactive
charts and GPU timelines are not part of this version; GPU engine summaries and
last observed region memory fields are shown, with full GPU time series in JSONL.

Artifacts:

- `manifest.json`: schema, run status/times, lens and executable hashes, target
  identities, context, protocol, warnings and SHA-256 hashes of raw files.
- `samples.jsonl`: monotonic elapsed time, phase label/generation, process identity, raw integer
  counters, derived rates, GPU clients, optional task snapshots, intervals,
  collection cost and lateness. Task rates use each task's own monotonic timestamps.
- `events.jsonl`: run/trial lifecycle and exact timing evidence.
- `summary.json`: first/last available and sampled-peak memory, time-weighted CPU,
  observed I/O totals **with covered seconds**, successful-trial latency and all
  failure counts, task summaries and evidence limits; bound to run ID and raw hashes.
- `samples.csv`: long-form process procfs counters/rates (GPU/task detail stays in JSONL).
- `report.html`: Rust-generated, HTML-escaped static report. Spreadsheet formula
  prefixes in CSV labels are escaped too.

Raw files are flushed during collection; final JSON/HTML is written atomically.
Invalid/truncated JSONL, missing hashes, identity/schema errors and modified data
are rejected by `report`/`compare`. An unfinalized run is diagnostic raw evidence,
not a passing result. Disk/write failure or SIGKILL may prevent finalization;
there is no automatic recovery that converts such a run into complete evidence.
Raw samples are capped at 128 MiB, checking each complete encoded row before
writing so task-heavy batches cannot overrun the limit. Duration (1 hour), process count
(64), trial count (1,000), helper output (1 MiB each), and helper deadlines are
bounded. Disk usage across runs remains the operator's responsibility.

Comparisons require:

- Complete runs, the same lens hash/version/schema/protocol, clock tick frequency,
  process roles/member counts, machine/kernel and recorded environment/context.
  Candidate UI builds may differ; other executable hashes must match unless their
  exact role is explicitly declared with `--changed-scope` (see below).
- An explicit nonempty matching `--context` declaration covering real
  display/scale/refresh, renderer/backend, power mode, motion/theme, visibility,
  workload size and external service state. These are **not automatically verified**.
- Deployed QML identity: the lens infers an explicit process `--path`/`-p`, or accepts
  `--config-path /path/to/shell.qml`. Active scenarios discover the exact instance's
  path. A Nix store config path identifies immutable packaged code; for mutable
  configs only the entry file is hashed, not all imported dependencies. Use immutable
  builds for meaningful A/B comparisons. Checkout HEAD is never substituted for the
  deployed build.

### Comparing intentional daemon or observer changes

```sh
# For auto-discovered bar-daemon members (PID suffix deliberately omitted):
"$LENS" compare --baseline BASELINE --candidate CANDIDATE --output COMPARISON \
  --changed-scope related:bar-daemon
# With explicit --related-pid bar=PID capture labels, use --changed-scope bar instead.

# Only for deliberately reviewing a different lens executable:
"$LENS" compare --baseline BASELINE --candidate CANDIDATE --output COMPARISON \
  --changed-scope lens-observer
```

Repeat the flag for multiple changed roles. Unknown/absent roles fail closed; no
wildcard exists. This only relaxes the named executable fingerprint check (and
lens hash for `lens-observer`), never completeness, cadence, membership, version,
config-identity availability, machine or operator-context requirements. An actual
observer hash change produces **`conditional_descriptive_only`**, a prominent
confound warning and observer deltas. Collector equivalence is **not verified**;
such a comparison cannot isolate an application improvement. Exit success means
compatible descriptive evidence, not a performance pass.

Deltas now include all uniquely paired roles, with CPU/I/O covered seconds and
full resource coverage/provenance. Auto-discovered PID suffixes are ignored for
role matching, but ambiguous multiple-member roles are explicitly **unpaired**:
no arbitrary PID pairing, hidden aggregation or memory total. Use stable, distinct
`--related-pid LABEL=PID` labels when individual members must be compared. Custom
labels are preserved literally; `ui-host`, `lens-observer`, `related:` and
`ui-service-member:` namespaces are reserved. Thread identities/names are not
matched across runs.

Reports show deployed executable/config fingerprints and warn when no target
build change is observed. A source commit or microbenchmark improvement is not a
production deployment. Passive runs explicitly report that they contain no
responsiveness trials or operation-level benchmark evidence. Search/history
probes remain separate evidence, not imported UI latency measurements. Existing
schema-1 artifacts still load; absent task settings mean task sampling was disabled.

Comparison reports provide deltas only when the applicable checks match. No universal
regression/pass thresholds, p99, significance claims or 24-hour baseline expiration
are invented. Median/max and descriptive nearest-rank p95 (at least 20 successes)
are shown; failed/unfinished attempts are never hidden by successful medians.
Start with **three independent passive runs**, then 30 warm-open attempts per
surface. Repeat alternating A/B measurements; a single comparison is not a verdict.

## Counter semantics and limitations

- CPU: `100 × Δ(user+system ticks) / CLK_TCK / elapsed_seconds`. 100% is one core;
  multithreaded workloads can exceed it. Tick quantization is real.
- RSS/PSS are process memory observations, not allocator traffic. VmHWM is
  lifetime high-water. PSS denial is unavailable, not zero. First/last memory means
  first/last **available** observations, not guaranteed exact phase endpoints.
- `read_bytes`/`write_bytes` are storage accounting; `rchar`/`wchar` are syscall
  character traffic (possibly IPC). Cached/mapped reads, buffered writes and
  short bursts limit interpretation. No network throughput, storage latency or
  fsync durability is inferred.
- GPU: supported Linux DRM fdinfo only. Deduplicate device/driver/client IDs across
  descriptors and processes; a shared client belongs to the first observed scope
  in a batch, never both. Per-engine nanosecond deltas use the common ABI's capacity
  field (omitted means 1). Reset/implausible deltas and capacity changes are
  unavailable; raw counters remain. Memory regions/allocated/resident/shared fields
  overlap and are not summed. No fallback to unlabelled device-wide GPU totals.
- First samples, phase transitions, lost permissions, missing fields and resets
  produce null-with-reason rather than fabricated rates. Phase generations prevent
  computing a rate across an intervening phase too short for the sampler to see.
  GPU/PSS cadence gaps are
  distinguished from unsupported counters. No last-value continuation.
- Observer cost is measured, not assumed negligible. The plan's <1%-of-one-core
  passive overhead goal is **not yet certified across machines**; inspect
  `lens-observer`, collection times and late samples, and compare 250/1000 ms runs.
  Reports flag phases exceeding that provisional overhead goal. In a short live
  implementation smoke test, 1-second PSS/GPU sampling across the UI, bridge clients
  and all five daemons cost about 3.7% of one core in the lens; do not assume the
  all-scopes profile is free. Increase `--detail-ms` or reduce scopes as needed.

## Safety and validation status

Automated tests exercise synthetic CPU/memory/I/O processes, passive captures,
Ctrl-C, target exit, artifact corruption/truncation, comparisons, parser units,
PID reuse, DRM resets/alias identities, bounded helpers, fake-IPC stale data,
timeouts, visible drafts, rejected opens and cross-surface cleanup refusal.
A release-build read-only IPC diagnostic and passive multi-process capture were
also checked against the running Shelllist instance, including supported AMD DRM
engine/memory counters and offline report regeneration. These short uncontrolled
smoke runs are not baselines. Live active UI trials are deliberately **not** part
of tests and have not been run
as part of implementation. Run them yourself in an explicitly consenting session.
No application panel or production key behavior was changed, so existing Qt
interaction tests are untouched.

The [five-item performance review](../../docs/performance-review.md) records
application findings and the lens collector optimization. The opt-in
`profile_light_process_collection` Rust test measures 1,000 real light procfs
samples with task diagnostics disabled. Field tables are parsed once per sample and the initial identity stat
is reused; pre/post process identity guards remain. This does not eliminate
PSS/kernel walk costs or justify silently increasing collection rates.

See [review.md](review.md) for the five-improvement effectiveness assessment,
implemented follow-ups, live watcher-thread validation and remaining limitations.
