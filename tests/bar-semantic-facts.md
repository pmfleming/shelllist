# CQ-10 / CQ-13 — semantic facts implementation checkpoint

Implementation evidence only; required exact-session Rust/QML quality review and
coordinator acceptance are separate. Bridge remains default. No deployment,
hardware service, host-bus/compositor, clipboard or desktop effects were exercised.

## Source and behavior

Baselines: bar-daemon `83658f4d537850941765bae10c4fc8ed3ac27b6e`, Shelllist
`6f14ede26d27cff03b72e51f647ee5e96dba6928`; no seeds. Framework
`563e7f95e0b976e1e2eb483bc4e983623f0e8fc5`, update-daemon
`7c3432f22ea82ebcd941f6ce8bcd562e2724d130` remain unchanged. Producer contract:
`bar-daemon/contracts/bar-semantic-facts.md` in the sibling family.

- Battery tooltip consumes native percentage/power and new estimate/health/cycles
  labels. Missing power is not 0 W; explicit native fully-charged state alone
  yields that label/check. Gauge geometry, animation, warning/critical flags and
  glyphs remain local. Native thresholds/calibration/critical/admission unchanged.
- Percent OSDs require available finite numeric observations before labeling;
  unavailable/null/nonfinite/invalid is not 0%. Pixel clamps remain local.
- Native `next_manual_profile` is absent unless at least two supported advertised
  profiles and a known current member permit cycling. Extensions never become
  targets. One explicit bar route captures/submits it; pending/absent/unavailable
  state sends nothing, stale publications cannot restore an older target, and
  failures require explicit retry. Native envelope membership is revalidated
  before pause persistence or hold release; removed targets leave holds intact.
- Refreshed native API/protocol and every affected nested read/control/battery/
  display/notification fixture. No media/clock/updates/network-kind conversion,
  shared Io/Core/generator, lock, default or threshold changes.

## Checks and reproduction

Working directory for commands below is this task's `worktrees/` family:

```sh
CHECK=/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/check.sh
$CHECK timeout 1800 nix develop ./daemon-framework --no-update-lock-file \
  --command bash ../check-final.sh
$CHECK timeout 1800 nix develop ./daemon-framework --no-update-lock-file \
  --command bash ../check-nix.sh
```

Drivers/logs are retained under task
`/home/laufan/Projects/shelllist-orchestration/20261026T202406Z/tasks/05-bar-semantic-facts/`.
`check-final.sh` passed (`logs/final2.log`, exit 0):

- Rust: 226 library + 29 update-worker + one ordinary native integration passes;
  deliberate ignored cases retained. Serial all-target rerun, strict all-target/
  all-feature Clippy, formatting and matching debug build pass.
- TypeScript: strict per-source compilation/generated-JS parity and
  `tsc --project tsconfig.json` pass. Neither Lens certifies TypeScript.
- Generated contract negatives/production fixture validation and offline
  `cargo xtask contract bar` pass.
- Actual Qt: **460 passed, zero failed, one existing renderer skip**. New tests
  exercise native labels/state, unknown/zero gauge and OSD, disabled/missing/
  extension target, the actual bar command route, pending guard, captured target,
  failure without retry, stale publication and explicit retry. Existing battery
  safety/transactions/recovery and other domain suites remain present.
- QML lint, surface catalog, source build-input checks and matched sibling-source
  Nix `buildInputs` pass. All use capture/preflight; no override/bypass.
- Private Quickshell socket probe passes: actual admitted service/serializer,
  shared reads/publication race/renewal/peer survival. It complements recording
  Qt command tests; it is not a native hardware-effect or whole-panel journey.

Matched sibling-source Nix `barDaemonContract` and `qmlTests` pass
(`logs/nix.log`, exit 0): 231 release library + 30 update-worker + two native
integration passes, and **460 Qt passes / zero failures / one existing skip**.
The existing synthetic watcher-registration timing smoke is not a final latency
or memory measurement.

Debug binary SHA-256:
`6bf3d5d9734638a712cd973ebb7ba6b38f2766c889a03b2c0cca120d4cec0b71`
(`bar-daemon/target/debug/bar-daemon`). Rust/Cargo 1.95.0; Qt 6.11.1.
Quickshell 0.3.0:
`/nix/store/nm6wrf4gprrxlri8nr16kcmixpkk8hrf-quickshell-0.3.0/bin/quickshell`,
SHA-256 `5ff1892ae380a2630a79e1caf3cfbc111309bfc878cd79415aeaeab7d020c980`.
Sibling source/store maps are preserved in the logs. Later evidence-only text
changes do not change the tested runtime sources.

## Safety, failures and remaining gates

Every heavy check used the shared lock, bounded timeout, private HOME/XDG,
unavailable host buses/compositor, offscreen/software Qt and two build workers.
The power fake is a point-to-point peer. Native routing starts no monitors and
allows only cached reads/subscriptions; its bus has no activation service dirs or
helper, frontend environment is cleared, and fixture children are bounded/cleaned.

Retained failures: initial missing `cc` before matching shell; test-development
internal-type/relative-import/recording-route mistakes; one preflight race while
adding a tracked contract. These were corrected, not skipped. A second parallel
producer suite hit `ETXTBSY` executing the unchanged brightness fixture's temporary
script (`logs/final.log`); its isolated rerun and full serial suite passed
(`logs/final2.log`). That unrelated underlying fixture race is not fixed or
claimed understood. The first full parallel suite also passed.

No final latency/memory benchmark or rollout acceptance is claimed. For a later
**exclusive serial** matched-release correctness rerun, freeze accepted heads,
Git-add new inputs, then run the two commands above (Nix package checks build/test
release sources). Preserve returned store paths and binary hashes before the
private probe. Final bridge/socket p50/p99/process-tree RSS/PSS comparison still
needs the coordinator's approved producer adapter/workload/sample/closure recipe;
this correctness probe is not a substitute. Do not run final measurements while
other workers/builds are active. Startup/upgrade/rollback/hardware/durable-outcome
qualification remains separate from these semantic tickets.

### Unfinished assigned row: upstream battery acquisition validity

CQ-10 remains **partial**, despite passing checks for the implemented tranche.
Source inspection found these unchanged witnesses (no fresh hardware reproduction):

- `bar-daemon/src/battery/upower.rs::read_state` uses `unwrap_or(0.0)` for missing
  Percentage and casts to u8; nonfinite Percentage/Capacity can also become zero,
  while `available` remains true for a present battery.
- `bar-daemon/src/battery/sysfs.rs::read_battery` uses `unwrap_or(0)` when both
  capacity and energy-ratio evidence are missing. Aggregate percentage may then
  be presented as a known 0%.

The current native DTO lacks a separate percentage-validity fact, so the new
consumer cannot reconstruct what acquisition discarded. This requires a bounded
follow-up native validity contract through acquisition/aggregation/display/gauge,
finite health validation, native fake-provider missing/zero/negative/nonfinite
vectors and matching Qt/serializer fixtures. Preserve warning/critical,
calibration and admission safety explicitly; do not simply change thresholds,
mark missing healthy, or manufacture the fact in QML. CQ-13's implemented cycling
and this checkpoint's unit/OSD/state corrections do not close that remaining row.

Required next gate: exact-session full-baseline Rust and QML/JS Lens
BEFORE/triage/refactor/AFTER, affected checks and quality evidence commit, followed
by coordinator review. No quality completeness claim is made here.
