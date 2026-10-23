# Shelllist xtask

Standalone Rust development tooling, with its own locked dependency graph. Run
from the Shelllist root; `.cargo/config.toml` supplies the `cargo xtask` alias.
`--root PATH` can select another captured checkout. The packaged executable is
`nix build .#xtask` → `result/bin/shelllist-xtask`.

```sh
cargo xtask surfaces                 # regenerate QML metadata
cargo xtask surfaces --check         # reject stale/missing output
cargo xtask build-inputs             # audit current sibling worktrees
cargo xtask build-inputs --sources sources.json --policy contracts/build-inputs.json
cargo xtask trim-cache               # dry-run, 4 GiB per target
cargo xtask trim-cache --apply --max-gib 8
cargo xtask check-daemon-boundary
cargo xtask check-ip-validation
cargo xtask contracts --nix          # producer tests/builds in each sibling dev shell
# Or, with all native build dependencies already available:
cargo xtask contracts
# Check an already-built (or packaged) producer without Cargo/Nix:
cargo xtask contract bar --bin ../bar-daemon/target/debug/bar-daemon
cargo test --locked --manifest-path tools/xtask/Cargo.toml
cargo clippy --locked --manifest-path tools/xtask/Cargo.toml --all-targets -- -D warnings
```

## Ownership and safety

- **Surface generation:** strict catalog parsing, reserved IDs/shortcut collisions,
  loading/residency validation, deterministic output and freshness. The Nix-side
  module evaluator remains; controller factories stay typed QML, not generated.
- **Build inputs:** reads only the supplied source graph, Cargo TOML/locks, compiler
  pins and vendored matcher. No Cargo resolution, network, Git hooks or source
  modification occurs during this check. Independent crates have exact documented
  exceptions, not directory-wide exemptions. Nix platform/toolchain gates remain.
- **Cache trimming:** native inode/block accounting and Linux Cargo-compatible file
  locks. Dry-run is now the default; deletion requires `--apply`. Tracks files with
  Git fsmonitor/hooks disabled; refuses external, symlinked and nested-repository
  targets. Preserves lock inodes, source/tracked content, unknown directories and
  reports. Retained hardlinks count once, exclusions are literal paths. Incremental
  caches precede coverage and ordinary artifacts. Any eligible active profile skips
  the entire target. Unreadable trees fail closed. This is not a concurrent-build
  scheduler. Tests delete only temporary fixture artifacts, never real caches.
  `CARGO_TARGET_DIR`, `CARGO_TARGET_MAX_GIB`, and legacy `SCRATCHPAD_TARGET_MAX_GIB`
  are supported; `--max-gib 0` disables cleanup. See [cache scope](../../BUILD-CACHE.md).
- **Contracts:** producer crates' `frontend_contract` tests deserialize checked
  payloads using their actual serde types, with malformed-type tests and preserved
  semantic witnesses. Serialize-only output types acquire test-only deserialization;
  no new live parsing or weaker runtime guards are introduced. NM's static label
  tables borrow small fixture allocations retained for the test process lifetime.
  Bluetooth audio now has a shared live wire DTO: the new check caught missing
  endpoint metadata in its old hand-written fixture. Dynamic registry/envelope
  projections still use semantic assertions rather than fake parallel DTOs.
  The xtask compares each offline producer export to the frontend JSON copy,
  checks registry coverage (including exact NM subscription policy), and app's
  resource fixture. Nix combines producer package tests with these parity checks.
  Exports give NM a private temporary log rather than touching the user's log or
  a shared file. `contracts` runs locked Cargo tests/builds and honors Cargo's
  reported executable path. `--nix` supplies each sibling's dependencies, including scoped clipboard
  bootstrap; neither mode deploys or contacts live desktop services.
- **Frontend regressions:** the former Node checks now run the actual Qt engine,
  QML transport/session objects and IP editor. The Rust commands invoke
  `qmltestrunner` directly with the existing offscreen/software/UTC setup and mock
  transports. They do not extract QML functions into a different JS runtime or
  duplicate IP-editing policy in Rust. Set matching Qt SVG/font/timezone environment
  as for `tests/run-qml-tests.sh`. Full `checks.qmlTests` owns these cases in Nix.

The removed Python generators/checks, jq assertions, shell contract checks and
Node boundary/validator checks are not kept as alternative implementations.
Other tooling (e.g. generated-JS runtime tests and the update-daemon's separate
packaged ecosystem-maintenance service) is outside this migration.
