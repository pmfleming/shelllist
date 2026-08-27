# Shelllist daemon common-library extraction plan

## Purpose

Extract stable, reusable infrastructure from the five Rust daemons used by Shelllist:

- `app-daemon` / `app-api` v1;
- `bar-daemon` / `bar-api` v1;
- `bt-daemon` / `bt-api` v1;
- `clip-daemon` / `clip-api` v1;
- `nm-daemon` / `nm-api` v1.

The extraction must reduce duplicated transport, ownership, envelope, lifecycle, protocol-test, and persistence code without moving domain policy out of its owning daemon or changing any frontend contract.

## Reassessment

The largest common boundary is still the JSONL frontend bridge. The five `src/client.rs` files now total roughly 1,670 lines and all implement the same wire operations:

```text
call(method, params)
subscribe(streams)
cancel(request_id)
shutdown
```

They also all forward the same D-Bus signal shape:

```text
Event(stream, event_json)
```

The four original Tokio daemons share the same basic proxy, stdout lock, request enum, event decoder, and response constructors. The newly Tokio-orchestrated `nm-daemon` has a more complete ordered-output actor: it tracks active operation/subscription IDs, buffers a fast event until the response exposing its ID has been written, drains concurrent calls, cancels active work on EOF, watches daemon ownership, and performs bounded shutdown. Those semantics are useful to all daemon clients, but NetworkManager's response correlation and unit-returning D-Bus `Cancel` must remain configurable.

Other repeated boundaries are:

- API success/error envelopes carrying protocol and version;
- event-envelope construction;
- D-Bus endpoint constants;
- JSON parameter decoding;
- directed signal emitters;
- D-Bus owner-loss monitoring;
- subscription ID generation and task registries;
- SIGINT/SIGTERM handling;
- debug registry/fixture printing;
- protocol fixture loading, uniqueness checks, and registry comparisons;
- XDG config/state/cache/runtime path resolution;
- private directory creation and atomic JSON replacement.

The protocol and daemon files have low whole-file textual similarity because their domain dispatch and event sources are genuinely different. The common library should therefore expose small types and functions, not replace daemon modules with a large generic framework.

## Inconsistencies to resolve deliberately

Extraction must choose and test canonical behavior rather than preserve accidental divergence:

1. `bar-daemon` verifies the caller before cancelling a subscription; `app-daemon`, `bt-daemon`, and `clip-daemon` do not consistently enforce that check.
2. `app-daemon` subscriptions are not destination-addressed and are not removed when their D-Bus owner disappears.
3. The application and clipboard JSONL event forwarders can end silently. Bar, Bluetooth, and NetworkManager report transport failure more reliably.
4. Daemon-restart detection is not consistent across JSONL clients.
5. EOF and shutdown handling ranges from detached calls to complete draining with a timeout.
6. `nm-daemon` buffers correlated events so a request event cannot overtake its response; the other clients can currently race.
7. Four daemons return JSON from D-Bus `Cancel`; `nm-daemon` returns unit and emits cancellation events.
8. API error envelopes differ intentionally in optional `retryable`, `details`, and `data` fields.
9. Storage implementations differ in permissions, durability, locking, corruption handling, and sync versus async I/O.

Owner isolation, directed signals, restart reporting, ordered output, and bounded shutdown should become common guarantees. Envelope and storage differences should be represented as explicit options rather than flattened.

## Proposed repository and crates

Use the separately versioned [`daemon-framework`](https://github.com/pmfleming/daemon-framework) repository as a Cargo workspace:

```text
daemon-framework/
  Cargo.toml                 # workspace
  Cargo.lock
  flake.nix
  crates/
    shelllist-daemon-core/
      src/
        endpoint.rs
        envelope.rs
        event.rs
        id.rs
        jsonl_wire.rs
        protocol.rs
        state.rs
    shelllist-daemon-tokio/
      src/
        jsonl.rs
        output_actor.rs
        dbus.rs
        subscription.rs
        shutdown.rs
    shelllist-search/
      src/
        lib.rs
        main.rs
  tests/
    conformance/
```

`daemon-framework` is the repository and release workspace name; the package names remain `shelllist-daemon-core`, `shelllist-daemon-tokio`, and `shelllist-search` so their responsibilities stay explicit.

Splitting the pure core from Tokio/zbus integration matters because `nm-daemon` still uses blocking zbus for its NetworkManager system-bus domain connection, while the other daemons enable zbus's Tokio integration. Enabling a zbus runtime feature is dependency-wide and should not be forced on a daemon merely to use envelope or fixture helpers.

`Shelllist-search` belongs in the same workspace because it is another Shelllist-owned Rust process boundary and can share workspace release, lint, Nix, and JSONL testing infrastructure. Its fuzzy-ranking algorithm and search request/response model remain independent of daemon transport APIs. Co-location does not require it to depend on either daemon crate.

### Compatibility targets

- Edition: 2024.
- Minimum supported Rust: 1.85, matching the oldest explicit daemon floor.
- Core dependencies: `serde`, `serde_json`, and optionally `anyhow`.
- Tokio crate dependencies: `tokio`, `futures`, `zbus` 5, and the core crate.
- No BlueZ, NetworkManager, PipeWire, Hyprland, clipboard, notification, or UI dependencies.

## Intended APIs

The exact API should be driven by conformance tests, but the initial shape should remain small.

### Core identity and envelopes

```rust
pub struct ApiIdentity {
    pub protocol: &'static str,
    pub version: u32,
}

pub struct DaemonEndpoint {
    pub executable: &'static str,
    pub bus_name: &'static str,
    pub object_path: &'static str,
    pub interface: &'static str,
}

pub fn success(api: ApiIdentity, data: Value) -> Value;
pub fn error(api: ApiIdentity, error: ApiError) -> Value;
pub fn decode_params<T: DeserializeOwned>(json: &str) -> Result<T, DecodeError>;
```

`ApiError` should use optional fields with omission preserved, so adding the helper does not add `retryable`, `details`, or `data` to contracts that currently omit them.

### JSONL wire types

```rust
pub enum ClientRequest {
    Call { id: String, method: String, params: Value },
    Subscribe { id: String, streams: Vec<String> },
    Cancel { id: String, request_id: String },
    Shutdown { id: String },
}

pub enum ClientMessage {
    Response { id: String, response: Value },
    TransportFailure { id: String, error: String },
    Event { stream: String, event: Value },
    ProtocolError { error: String },
    TransportError { error: String },
}
```

Serialization tests must pin the existing `kind`, `id`, `ok`, `response`, `stream`, `event`, and `error` names.

### Ordered output actor

```rust
pub trait CorrelationPolicy: Send + Sync + 'static {
    fn response_ids(&self, response: &Value) -> ResponseIds;
    fn event_id(&self, stream: &str, event: &Value) -> Option<&str>;
    fn is_terminal(&self, stream: &str, event: &Value) -> bool;
}
```

Provide:

- `SubscriptionCorrelation` for the four simpler clients;
- an `nm-daemon` policy that additionally derives operation/continuous delivery from its stream registry;
- bounded pending-event storage;
- one stdout owner so concurrent output cannot interleave;
- response-before-event release;
- active ID snapshots for EOF cleanup.

### D-Bus JSONL bridge

```rust
pub trait TransportPolicy {
    fn call_failure(&self, error: anyhow::Error) -> CallFailure;
    fn decode_cancel_reply(&self, reply: CancelReply) -> Result<Value>;
}

pub async fn run_jsonl_client<P, C>(
    endpoint: DaemonEndpoint,
    transport: P,
    correlation: C,
) -> anyhow::Result<()>;
```

The runner owns request parsing, concurrent calls, event forwarding, owner watching, ordered output, EOF cleanup, and bounded shutdown. Policy hooks preserve the current distinction between API-level daemon-unavailable envelopes and JSONL transport failures, and between JSON-returning and unit-returning `Cancel` methods.

### D-Bus ownership and subscriptions

```rust
pub fn directed_emitter(
    emitter: &SignalEmitter<'_>,
    header: &Header<'_>,
) -> SignalEmitter<'static>;

pub async fn wait_for_owner_loss(
    connection: &zbus::Connection,
    owner: UniqueName<'static>,
) -> anyhow::Result<()>;

pub struct OwnedTaskRegistry { /* private */ }
```

`OwnedTaskRegistry` should provide atomic IDs, owner-associated task insertion, owner-checked cancellation, task self-removal, and owner-wide cleanup. It should manage subscription tasks only; domain operation cancellation remains local.

### Events, shutdown, and protocol checks

```rust
pub fn event_envelope(
    api: ApiIdentity,
    stream: &str,
    event: &str,
    correlation: Correlation,
    fields: Value,
) -> Value;

pub async fn wait_for_shutdown() -> anyhow::Result<()>;
pub fn checked_fixture(source: &str) -> serde_json::Result<Value>;
pub fn validate_unique_names(values: &[&str]) -> Result<(), DuplicateName>;
pub fn fixture_registry_names(fixture: &Value, section: &str) -> Result<Vec<&str>>;
```

Interface-specific `#[zbus::signal]` methods remain in each daemon. The common library builds values and owns generic watches; it does not hide zbus interface definitions behind macros.

### State utilities

```rust
pub enum XdgRoot { Config, State, Cache, Runtime }
pub struct DirectoryPolicy { /* env overrides and permissions */ }
pub struct AtomicWritePolicy { /* modes, pretty JSON, fsync behavior */ }

pub fn resolve_xdg_path(...);
pub fn read_json<T: DeserializeOwned>(...);
pub fn write_json_atomic<T: Serialize>(...);
```

The secure implementation should use a unique temporary file, no-follow checks where required, explicit directory/file modes, file sync, atomic rename, and optional parent-directory sync. Advisory locking, cache read states, history rotation, and domain validation remain in `nm-daemon` and the relevant owning daemons.

## What must remain daemon-local

Do not extract:

- domain models or API method dispatch;
- NetworkManager, BlueZ, PipeWire, Ringboard, battery, notification, application-resource, or SecretAgent policy;
- stream snapshot construction, refresh coalescing, and domain event payloads;
- operation state machines and cancellation/rollback semantics;
- typed domain error taxonomies;
- protocol method and stream declarations;
- `nm-daemon`'s bounded NetworkManager work lanes;
- daemon-specific CLI probes and maintenance commands;
- compositor code into the general daemon crate.

Hyprland socket discovery and request/event I/O shared by application and bar daemons is a valid later extraction, but should live in a separate `shelllist-hyprland` crate.

## Delivery plan

### Phase 0: freeze contracts and transport behavior

1. Add a common JSONL conformance document and golden messages.
2. In every daemon, test malformed input, blank lines, all four operations, concurrent calls, unavailable D-Bus, daemon restart, EOF, shutdown timeout, and atomic output.
3. Add two-owner D-Bus tests proving directed delivery and owner-scoped subscription cancellation.
4. Preserve every checked API fixture byte-for-byte or structurally, according to its current check.
5. Record intentional transport differences as policy cases.

**Gate:** no extraction begins until the tests detect every inconsistency listed above.

### Phase 1: establish the `daemon-framework` workspace

1. Create `github.com/pmfleming/daemon-framework` with a virtual Cargo workspace and one shared lockfile.
2. Add workspace-wide formatting, Clippy with warnings denied, test, MSRV, audit, and Nix checks.
3. Move the current Shelllist `shelllist-search` package into `crates/shelllist-search` without changing its binary name or JSONL request/response contract.
4. Split search ranking into `lib.rs` and retain a thin `main.rs`, so ranking and process-boundary tests remain independently testable.
5. Export `packages.<system>.shelllist-search` and a runnable app from the framework flake.
6. Change Shelllist's flake to consume the framework package and remove its local `Cargo.toml`, `Cargo.lock`, and `src/` only after the external package passes the existing QML integration.

**Gate:** `shelllist-search` behavior and executable name are unchanged, Shelllist no longer builds Rust source from its own repository, and the framework workspace is independently buildable.

### Phase 2: create and release `shelllist-daemon-core`

1. Add `ApiIdentity`, `DaemonEndpoint`, wire request/message types, envelope builders, ID generation, fixture helpers, and pure event construction.
2. Test optional envelope fields and exact JSONL serialization.
3. Test on Rust 1.85 and latest stable through workspace CI.
4. Tag an initial workspace `0.1.0` release.

**Gate:** core has no async runtime or domain dependencies.

### Phase 3: migrate pure helpers

Migrate in this order:

1. `app-daemon` as the smallest protocol implementation;
2. `clip-daemon` for fixture and richer error-envelope coverage;
3. `bar-daemon` for generated fixture coverage;
4. `bt-daemon` for rich protocol metadata and retryable errors;
5. `nm-daemon` for typed details and mandatory error data.

Each migration is one daemon-local commit and must pass that daemon's Cargo/Nix checks plus Shelllist's matching contract check.

**Gate:** duplicated request enums and basic envelope constructors are gone, with no contract changes.

### Phase 4: create the Tokio transport crate

1. Extract the ordered-output actor from the proven `nm-daemon` behavior.
2. Add the basic and NetworkManager correlation policies.
3. Add the generic D-Bus proxy, event forwarder, daemon owner watcher, active-ID cleanup, and five-second shutdown drain.
4. Support JSON and unit `Cancel` replies.
5. Support daemon-specific call-failure mapping.
6. Run fake D-Bus integration tests under service absence, activation, restart, and event/response races.

**Gate:** the transport crate can express every existing client without daemon-name branches.

### Phase 5: migrate JSONL clients

Migrate one daemon at a time:

1. `app-daemon`: also add destination-addressed subscriptions and owner cleanup;
2. `bar-daemon`: retain its current restart and owner protections;
3. `clip-daemon`: retain the separate raw-byte `Publish` helper;
4. `bt-daemon`: retain structured logging and task naming around the shared runner;
5. `nm-daemon`: retain registry-derived event correlation and unit-cancel behavior.

Do not migrate all clients in one changeset. Build and exercise Shelllist after each daemon so a rollback only changes one process boundary.

**Gate:** each daemon's `client.rs` is a small endpoint/policy adapter, daemon restart always produces `transport-error`, and EOF/shutdown cannot lose accepted calls.

### Phase 6: extract owner-safe subscription primitives

1. Implement directed emitter, owner watch, and `OwnedTaskRegistry`.
2. Migrate bar first because its owner-checked cancellation is the reference behavior.
3. Migrate Bluetooth and clipboard.
4. Migrate applications, fixing its broadcast/orphan behavior under explicit security tests.
5. Reuse only owner-watch primitives in NetworkManager; its subscription actor and domain cancellation remain local.

**Gate:** caller A cannot cancel or receive caller B's subscription in any daemon, and client disappearance removes all owned subscriptions.

### Phase 7: extract shutdown and debug helpers

1. Share SIGINT/SIGTERM waiting.
2. Share pretty JSON debug output and registry/fixture command handling where it reduces code without constraining extra CLI commands.
3. Keep Clap command enums and tracing policy local unless two implementations are genuinely identical after configuration is accounted for.

**Gate:** no daemon loses its probes, logging fields, or cleanup hooks.

### Phase 8: extract storage primitives

1. Start with Bluetooth's private state store and clipboard's durable atomic replacement tests.
2. Define explicit permission and durability policies.
3. Migrate simple application and bar JSON files.
4. Reuse low-level functions in NetworkManager only where they preserve its locking, no-follow, corruption-state, rotation, and transaction guarantees.

**Gate:** secure stores stay mode `0700`/`0600`, crash replacement tests pass, and no repository-level locking semantics are weakened.

### Phase 9: consider compositor extraction separately

Compare `app-daemon/src/hyprland.rs` and `bar-daemon/src/hyprland.rs` after transport extraction. If their socket discovery and request/event handling can share one API without merging domain models, create `shelllist-hyprland`. Otherwise leave them separate.

## Packaging and versioning

The daemons and Shelllist are independently buildable repositories, so do not commit sibling path dependencies. Use one of:

1. publish the crates and pin compatible semver versions; or
2. initially pin an exact Git revision and add the required Nix Cargo output hash.

Crates.io publication is preferable once the API settles because it simplifies each `buildRustPackage` derivation. The `daemon-framework` workspace should use semantic versioning, a changelog, and CI against every daemon before a breaking release. Workspace releases may share one tag while each crate keeps its own package version.

Shelllist needs a `daemon-framework` flake input for the packaged `shelllist-search` executable. It does not need to link the daemon libraries directly: each daemon package owns those Rust dependencies. Shelllist continues pinning daemon outputs and validating their frontend contracts.

## Validation matrix

For every framework release:

- framework workspace format, Clippy, unit, integration, MSRV, and documentation tests;
- `shelllist-search` ranking, malformed-input, JSONL process, and QML integration tests;
- `cargo test` and Clippy in all five daemons;
- `nix flake check` in all five daemons;
- all five Shelllist contract scripts;
- Shelllist QML/JavaScript tests and `nix flake check`;
- an end-to-end restart test for each daemon client;
- two-owner subscription isolation tests;
- malformed JSON, event-before-response, EOF, and bounded-shutdown tests;
- storage permission and crash-replacement tests where state helpers change.

## Completion criteria

The extraction is complete when:

- `shelllist-search` is built and released from `daemon-framework`, with Shelllist consuming the packaged executable;
- all five daemons use one JSONL request/message definition;
- all five use one tested ordered-output implementation;
- all JSONL clients detect daemon replacement and shut down within a bound;
- subscriptions are destination-addressed, owner-scoped, and automatically cleaned up;
- API/event envelopes and protocol fixture checks use common pure helpers;
- repeated XDG/atomic JSON code uses explicit shared policies where semantics match;
- existing API fixtures and Shelllist behavior remain compatible;
- each daemon remains independently buildable and releasable;
- the common crates contain no domain policy or system-integration dependencies.
