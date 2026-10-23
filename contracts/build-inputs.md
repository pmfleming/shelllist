# P6: product build inputs and workspace decision

## Decision

**Retain the multi-repository build graph and ten owning Cargo locks.** P6's
conditional product-workspace migration is not approved by this change. Do not
merge Git histories, delete old checkouts/locks, rename services, or move privilege
boundaries. Compiler/dependency alignment is independently deployable. A future
workspace proposal needs explicit approval and native validation on the supported
x86_64-linux platform before changing source roots and Crane cache boundaries.

The product policy is `contracts/build-inputs.json`, enforced by
`cargo xtask build-inputs` and `checks.<system>.buildInputs`. This is a small
policy/inventory, not another dependency resolver or a generated universal
workspace. Cargo and the existing locked, offline Nix builds remain authoritative
for features and transitive resolution.

## Supported platform and CPU scope

**x86_64-linux only**, primarily modern Intel and AMD desktop/laptop CPUs.
ARM/aarch64, 32-bit x86 and other operating systems are outside product support
and are not release gates. Flake package/check/app/developer-shell outputs,
package metadata and host-supplied compiler/worker guards enforce this scope.
The product input check rejects platform drift and tests unsupported-target
rejection without needing an ARM builder.

Keep the existing portable x86-64 build baseline. Modern Intel/AMD is the primary
testing/performance target, not a new instruction-set minimum: do not introduce
`target-cpu=native`, `-march=native`, mandatory AVX2/x86-64-v3, or a vendor-specific
CPU target. No CPU-generation cutoff is imposed and no additional testing of
older CPUs is claimed. This change narrows support; it does not retune binaries.

## Compiler and actual build inputs

Select **Rust/Cargo 1.95.0**, satisfying the highest declared product MSRV (clip's
1.95). Lower crate MSRVs are not silently raised, nor are they claimed to have
been retested on their minimum compilers. All eight repositories now declare an
exact rustup channel. Existing GitHub Actions Rust installs are pinned to that
same release (including the local-build bootstrap); standalone Cargo CI uses
`--locked`. The obsolete framework 1.85/stable matrix is replaced by the supported
product compiler, not advertised as continuing MSRV coverage. Framework consumer
CI and both bar workflows now capture the update-worker/status-contract sibling.
Framework `lib.toolchain` checks the actual Nix rustc,
Cargo, Clippy and rustfmt packages and the rustPlatform compiler/Cargo pair.
Crane packages and developer shells use that guard. Shelllist's search, portal
and timezone packages use the guarded rustPlatform. The separately packaged
worker checks its host-supplied rustPlatform against its own channel file; it
still has no framework or nixpkgs flake dependency.

All seven existing nixpkgs locks now use the already-tested **Shelllist product
pin**, `8eeec934ae0dbeca3d7868c059568a65c08b2fc3` (nixos-26.05). This deliberately
selects the existing product build input rather than updating the product to the
newest standalone daemon pin. Nix input overrides that change the product pin
fail the product gate, even if they retain Rust 1.95.0.

Measured x86_64-linux build environment from the Nix check:

| Input | Actual value |
| --- | --- |
| Builder invocation | Nix 2.34.8, sandbox enabled |
| Pinned nixpkgs Nix package | 2.34.7 (not the invoking Nix executable) |
| rustc | 1.95.0, commit `59807616e1fa2540724bfbac14d7976d7e4a3860` |
| rustc target / LLVM | x86_64-unknown-linux-gnu / 21.1.8 |
| Cargo | 1.95.0 |
| native CC | GCC 15.2.0 |
| libclang / PipeWire | 21.1.8 / 1.6.5 |
| systemd / D-Bus / Wayland | 260.2 / 1.16.2 / 1.25.0 |

The check output contains `build-inputs.json`, captured source paths, and executed
`rustc -Vv`, `cargo -Vv`, rustfmt and Clippy version reports. These are build
artifacts, not assertions inferred only from rustup files. The Nix check also
fault-injects a mismatched compiler to test the fail-closed guard. An actual
`nix develop ... --command` run also reported the identical rustc/Cargo versions
and store paths (`/tmp/p6-devshell.log`), confirming developer/build agreement.

## Dependencies and exceptions

All shared direct requirements are checked, including dev/build and
target-conditional dependencies. Exact resolutions for shared dependencies
and key serializer/runtime/derive companions are checked in every owning lock
that contains them. In particular all five daemons and the framework resolve
zbus **5.18.0**, zvariant **5.13.1**, Tokio **1.53.1**, serde **1.0.229** and
serde_json **1.0.151**. The zbus/zvariant requirements now describe those supported
API lines; features remain domain-specific (including NM's blocking API and
private-bus test features). Chrono **0.4.45** is shared by the bar's clock and
the worker's UTC status formatter; their `clock` and `std` features remain
independent. No automatic dependency updates run in CI.

Exceptions have exact paths/versions and reasons in the policy:

- local-build's parse-only TOML 0.8 and clipboard's TOML 0.9 are distinct APIs.
  Native PipeWire build tooling uses TOML 1.1.4. Do not upgrade config parser APIs
  just to erase multiple major versions.
- The worker's HTTP/TLS transitive graph also needs base64 0.23; the shared direct
  API stays at 0.22.1.
- Clipboard's ignored `vendor/shelllist-search/Cargo.lock` can exist after a
  standalone library test but is not an owning product lock or Nix input.
- Clipboard still explicitly scopes `RUSTC_BOOTSTRAP` to the two pinned
  clipboard-history crates. This is a native dependency constraint, not a claim
  that every product dependency compiles without unstable features.

This is intentionally not a claim that *all* transitive packages have identical
versions across independent locks. Changing a shared requirement/resolution,
adding a shared dependency/crate/owning lock, or raising an MSRV beyond the
selected compiler requires a deliberate policy update. A one-off exception must
not become a blanket allowed-major-version range.

## Workspace scope and build constraints

| Candidate | Current ownership and constraints |
| --- | --- |
| Five session daemons | Separate Cargo roots and packages; MIT manifests. Keep per-domain features and bus/systemd names. App uses compositor IPC; bar/BT need PipeWire/libclang (shared writable bindgen fallback); bar also uses libudev/systemd, bundled SQLite, managed hypridle and installed protocol/data license notices. BT uses native D-Bus/BlueZ. Clip uses D-Bus, Wayland, image codecs and pinned clipboard-history crates. NM keeps its blocking/control paths and separate cast-policy package. |
| Framework | Existing four-crate resolver-3 workspace, MIT; core/tokio/Hyprland path crates and local-build tooling. Keep the filtered three-crate daemon source and shared workspace dependency cache. |
| Canonical search | `shelllist/rust/shelllist-search`, MIT; standalone binary/library and lock. Clip still builds the byte-checked vendor copy. Replacing it requires a cycle-free source input/package extraction: adding all of Shelllist as a clip input would create a flake cycle. The existing freshness gate is retained, not silently removed. |
| Update-status contract | MIT serde-only crate inside update-worker's existing workspace/lock, also captured explicitly for bar. Never import privileged implementation to obtain a DTO. |
| Update-worker | Separate finite privileged package and lock, configured by the host. Root Cargo manifest does not declare a license; resolve that metadata before any consolidation. Preserve test-support output, host configuration, transaction/state paths and separate deployment authority. |
| Portal launcher | Shelllist-owned MIT root/lock; source capture includes the current framework Hyprland crate. Keep its separate executable and portal/process behavior. |
| Timezone tooling | Shelllist-owned MIT root/lock; separate asset generator and generated-asset freshness gate. Its input data provenance/licenses remain separate from the executable license. |

This is a build/feature/license-constraint inventory, not a transitive license
compliance audit. A future approved workspace would include the five daemons,
framework and canonical search; update-status must stay independently consumable.
Whether the worker, portal and timezone tools join must be decided explicitly,
not by moving every nearby Cargo manifest into a root wildcard.

## Source capture and validation

Use `daemon-framework/tools/local-build` (or its packaged binary), not stale
local flake revision pins. The five-consumer current-framework invariant remains
unchanged. Shelllist now has an explicit `update-worker` input, and bar follows
it, so the worker/contract cannot accidentally come from an omitted sibling.
The input check receives **captured Nix source paths**, inventories all manifests
and owning locks, and checks every path dependency resolves inside that set.
Nix post-unpack source assembly and locked builds then prove actual compilation.

The product check matrix also includes the worker (isolated test configuration),
portal and timezone packages, alongside all five daemons, framework, search,
fixtures/TS/assets and native QML checks. Worker checks do not deploy, update a
live system, or introduce a framework dependency into the worker crate.

```sh
(cd shelllist && cargo xtask build-inputs)
cargo test --locked --manifest-path shelllist/tools/xtask/Cargo.toml build_inputs
# Run in the product developer shell, or use packaged local-build:
daemon-framework/tools/local-build check shelllist --keep-going
# Evaluate the complete supported output set (x86_64-linux only):
daemon-framework/tools/local-build check shelllist --all-systems --no-build
```

Only `x86_64-linux` package/check outputs are exposed. The former ARM execution
gate is withdrawn by the explicit supported-platform decision, not reported as
a passed ARM test. See `architecture-execution.html` for the measured results.

The initial P6 x86_64 capture passed compiler/policy checks and most locked
builds/tests, but concurrent P4/P5 changes blocked the full gate (see
`/tmp/p6-final-check.log`). That failure is historical: the subsequent P4 closure
records a complete passing x86_64 Nix gate in `/tmp/p4-nix-closed.log`, including
805 native QML passes (one skipped). Validation of this platform-scope change is
recorded separately in the execution ledger; neither historical run substitutes
for checking later concurrent work.

## Rollout / rollback

Ship build alignment separately from protocol migrations and repository moves.
No unit names, D-Bus names, installed binary names, helper privileges or persistent
state layouts change in P6. Previous immutable Nix closures/system generations
remain valid rollback targets. Roll back the compiler/dependency/input-policy
changes as a compatible set; do not rewrite existing closures or delete old
checkouts. Any later workspace/search-source migration needs its own review,
source-capture tests, package matrix and rollback plan.
