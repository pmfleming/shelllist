# Flicker and responsiveness improvements

Source baselines: Shelllist `bac786d`, app-daemon `5f29dcc`, daemon-framework
`89f766e`. Changes are coordinated across those three worktrees. No live panel
control, service restart, desktop rebuild or deployment was performed. The prior
performance-lens work, Shelllist fixture edit and incoming bar-daemon notification
edit were preserved byte-for-byte. Evidence: `target/responsiveness/`.

## 1. Keep accepted empty search results while ranking

`qml/Shelllist/Core/ResultStore.qml` previously used a nonempty result array as
proof of a prior ranking. Once a query returned zero matches, another keystroke
or catalog refresh temporarily exposed the entire catalog until Rust answered.
This produced avoidable result flicker and delegate churn.

An explicit accepted-window flag now distinguishes **empty** from **not yet
ranked**. Pending queries retain the accepted window; the first query retains the
existing baseline fallback, and clearing search restores the baseline immediately.
Owner/query generations still reject stale responses. The obsolete applied-generation
visibility flag was removed; request-generation ownership remains unchanged.

The native shared-chooser regression types successive queries, publishes an empty
ranking, refreshes the catalog, rejects a stale response and clears search. It
fails against the original ResultStore (2 transient rows instead of 0) and passes
with the change. Focus stays in search; no alternate keyboard model was introduced.

## 2. Do not reset keyed models for index shifts

`qml/Shelllist/Core/KeyedListModel.qml` previously interpreted a large prepend or
middle deletion as many reordered rows. Crossing 32 changed indexes cleared the
model, destroying otherwise unchanged delegates. Existing append-only paging
already avoided this problem, but other contiguous changes did not.

A linear prefix/suffix check now identifies pure contiguous insertion/removal.
Survivors stay instantiated, updated payloads still publish, and large insertions
reuse generation-fenced bounded chunks at an insertion offset. Genuine large
reorders retain the previous reset policy; this is not an unbounded quadratic
reconciliation change. Serialized notification reply models retain their existing
non-resetting reconciliation override.

Actual Qt tests verify native editor identity, focus and draft retention. Adding
40 rows before 80 existing rows creates exactly 40 new delegates and destroys
none; deleting 50 rows subsequently destroys only those keys. A superseded
chunked prepend cannot leak stale rows, and append paging still preserves
survivors. Both new regressions fail against the original model and pass now.
These are delegate-lifetime measurements, not compositor frame-rate claims.

## 3. Keep application queries off the async executor

`app-daemon/src/service.rs` previously grouped windows (including fallback procfs
reads), ranked candidates and projected resources synchronously on an async
executor thread. The projection also held settings/resource read locks, delaying
publication and potentially other requests during a large query.

Queries now capture immutable `Arc` snapshots and release state guards before
executing that work in the blocking pool. Settings/resources publish replacement
snapshots; no per-query deep copy of the whole resource graph is needed. Two
owned permits bound projection jobs, including jobs whose waiters were dropped.
Framework request admission separately bounds waiting API requests. Waiting for
projection admission holds no state locks. Worker failures map to the existing
unavailable response; ranking, revision checks and wire types are unchanged.

Tests gate a one-thread blocking pool and verify that a queued query yields,
settings/resources remain writable, revisions remain readable, and subsequent
publication cannot mutate the captured response. Dropping two query waiters does
not free their worker permits; later work resumes when those jobs actually finish.
Existing per-target action guards, query ranking and shutdown tests still pass.

This isolates work rather than reducing its total CPU. History persistence,
resource sampling cadence and operation lifetimes were deliberately not changed.

## 4. Isolate framework response serialization

`daemon-framework/crates/shelllist-daemon-tokio/src/service.rs` now serializes
admitted `run` results in a blocking job after domain work completes. Previously,
a large synchronous JSON serialization could monopolize an executor thread needed
for input, timers and other requests across any consumer of this shared path.

The job owns the original request permit and method/owner quotas until completion.
Read timeout or waiter cancellation cannot release capacity while an encoder is
still running. Effect execution, byte limits, failure/unknown outcomes and no-replay
rules remain intact. A single-thread runtime test gates a real serializer and
checks that another admitted request and cleanup capacity remain available;
both read and effect timeouts retain quotas until the encoder finishes.

Small responses pay an additional worker handoff. This is executor isolation,
not lower serialization CPU or a hard latency guarantee under saturation. It
does not move arbitrary CPU work inside handlers, event serialization, or direct
`encode` calls. The application-specific projection change addresses one such
handler explicitly. Shared framework source must be rebuilt into the consumers
before the running services benefit.

## Validation

| Boundary | Result |
| --- | --- |
| Shelllist full native Qt suite | 255 passed, zero failures, one existing renderer-only skip |
| New UI regressions against original source | Expected failures reproduced in isolated import copies; working source passes |
| QML/static checks | Strict lint, TypeScript generation, generated contracts, daemon boundary, packaged imports, runtime smoke and numeric UI review pass |
| daemon-framework workspace | 55 passed; one existing opt-in ignored |
| app-daemon, all features | 40 unit + 15 private-bus/compositor integration tests pass; existing opt-ins excluded |
| bar-daemon | 197 library + 29 location + 1 startup tests pass; existing opt-ins excluded |
| bt-daemon | 64 unit + 2 integration tests pass |
| nm-daemon | 87 unit tests pass; three existing opt-ins excluded |
| clip-daemon | 35 unit + 6 backend + 1 client tests pass |
| Changed Rust projects | Workspace/all-feature all-target Clippy with warnings denied; formatting passes |

Counts exclude nested child-test output from totals. Qt counts include lifecycle
hooks. An initial full Qt run concurrent with Rust builds had an asynchronous
ApplicationActions fixture-readiness failure; that suite passed independently
and the serial full run passed without changing or skipping the test. Bar and
Bluetooth required their documented Nix development environments for system
libraries. Clipboard used its documented scoped upstream bootstrap exception.
App tests used isolated XDG state/config paths. No hardware opt-in was enabled.

Reproduce from Shelllist (use the corresponding daemon dev shell where needed):

```sh
tests/run-qml-tests.sh
tests/run-qmllint.sh
cargo test --workspace --locked --manifest-path ../daemon-framework/Cargo.toml
XDG_STATE_HOME="$PWD/target/responsiveness/app-state" \
XDG_CONFIG_HOME="$PWD/target/responsiveness/app-config" \
  cargo test --all-features --locked --manifest-path ../app-daemon/Cargo.toml
```

The internal performance review/lens remains useful for deployment-aware resource
triage, but idle CPU capture cannot establish removed UI flicker or prove input
latency. Here the decisive evidence is native delegate/ranking behavior and gated
executor-progress tests. No numeric end-to-end latency speedup is claimed.
Follow-up acceptance should rebuild the coordinated graph, then run consent-gated
warm opens and controlled repeated search/list updates under the same compositor,
workload and observer. Full Nix packaging, actual compositor presentation and
human interaction/accessibility acceptance remain open.
