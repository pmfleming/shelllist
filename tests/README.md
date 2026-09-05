# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer one representative scenario or a labeled table over repeated
fixtures for the same behavior.

## Coverage to retain

- Daemon protocol fixtures and generated bindings, including request/event
  correlation and incompatible-envelope rejection.
- Shared-session recovery, late subscription replies, owner-scoped cancellation,
  response-before-event ordering, deadlines, and idle-listener survival.
- Secret handling, path confinement, private persistence, image allocation limits,
  stale revisions, and validation before destructive operations.
- Provider dispatch, asynchronous ranking, selection restoration, and domain
  lifecycle/presentation behavior.

## Coverage deliberately pruned

- Source-token checks that prescribe helper names, component composition, exact
  debounce durations, or obsolete migration structure.
- Trivial lookup/default/serialization helpers already exercised through broader
  behavior or protocol tests; tests of fake implementations rather than consumers.
- Duplicate happy paths and old storage-format/fallback-layout expectations that
  are not current compatibility requirements.

Closely related cases share fixtures where useful: error classification, network
health traces, profile updates, Bluetooth identity reloads, clipboard classification,
notification persistence, and battery history retention. Security and failure cases
remain explicit. Screenshot size limits are checked through the clipboard API, not
just its private validator. Timezone assets retain their generated-asset check rather
than hard-coded region counts or QML implementation assertions.

## Validation

Run `nix flake check --no-update-lock-file` in Shelllist and the shared framework.
The Shelllist checks include QML tests, JavaScript behavior, generated assets and
bindings, protocol contracts, lint, packaging, and runtime smoke coverage.

In each Rust repository, use its declared development environment:

```sh
nix develop --no-update-lock-file --command cargo test --offline
nix develop --no-update-lock-file --command cargo clippy --offline --all-targets -- -D warnings
nix develop --no-update-lock-file --command cargo fmt --all --check
```

Locked integration and candidate sibling-worktree integration are different checks;
do not update fixtures or locks merely to make a test-pruning change pass.
