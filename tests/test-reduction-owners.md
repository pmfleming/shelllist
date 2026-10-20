# Ecosystem ownership reduction — target reached

## Fresh baseline and result

**988 → 661 registered cases/suites: 327 removed, 33.10%.**
The strict maximum is `floor(988 × 0.67) = 661`. This pass reaches it without
adding tests, grouping former cases into loops, renaming tests into helpers,
changing discovery, adding skips, or relaxing acceptance/coverage thresholds.
Existing loops and data rows in retained tests are unchanged.

| Repository | Before | After | Removed |
| --- | ---: | ---: | ---: |
| shelllist | 342 | 122 | 220 |
| app-daemon | 60 | 44 | 16 |
| bar-daemon | 205 | 170 | 35 |
| bt-daemon | 60 | 47 | 13 |
| clip-daemon | 41 | 39 | 2 |
| nm-daemon | 106 | 95 | 11 |
| update-daemon | 112 | 95 | 17 |
| daemon-framework | 62 | 49 | 13 |
| **Total** | **988** | **661** | **327** |

| Unchanged inventory convention | Before | After |
| --- | ---: | ---: |
| Qt behavioral cases/data rows, including existing skip | 275 | 79 |
| Rust registrations, including Shelllist's 8 and existing ignores | 593 | 502 |
| Python test methods, including the native application journey | 99 | 72 |
| Behavioral JavaScript scripts | 16 | 3 |
| Daemon producer/consumer contract suites | 5 | 5 |

`count-ecosystem-tests.py` is byte-for-byte unchanged. Counts use fresh Cargo
`--list` output and a complete Qt run, not function-name estimates. A Rust
source declaration compiled into two targets counts twice before and after.
Assertions, subtests, lifecycle hooks, repeated helper-process executions and
vendored copies of the same tests are not separate registrations. External
VM/hardware/manual acceptance, static packaging checks and non-libtest benchmarks
remain outside this **registered-suite scope**, as in the preceding passes. This
is not a claim of 33% over every possible external acceptance entrypoint.

The tracked [inventory](test-reduction-owners-inventory.json) records all 327
retired registrations, repository revisions, incoming-file hashes and the baseline
archive hash. Matching discovery, source archive and logs are under
`target/test-reduction-owners/`. The incoming Shelllist build-input files and Bar
location documentation/flake remain byte-identical to the captured worktree.
Cargo manifests, lockfiles, runners and lint/discovery policy are unchanged.

## What changed in the approach

The earlier passes preserved almost every unique assertion and consequently
missed the requested scale. This pass assigns primary ownership at the behavior
boundary, then **retires noncritical detail coverage deliberately**. Not every
removed assertion is duplicated elsewhere. In particular, parser permutations,
telemetry arithmetic, presentation matrices and development-tool option variants
can lose direct assertions without being critical application protections.

195 Qt registrations were initially selected, followed by one additional media
fallback/geometry case during review. QR SVG secret-exposure checks, update
readiness compatibility/hash/path vectors, real worker failure/override refusal
and unlocked Cargo lock-inode preservation were explicitly retained rather than
calling them duplicates. The final reduction is 196 Qt, 91 Rust, 27 Python and
13 JavaScript registrations. No per-repository quota was imposed; Clipboard loses
only two redundant projection/correlation cases because its remaining suite is
predominantly safety and native workflow coverage.

One existing native application metadata journey now queries `OK` through the
real D-Bus API and requires only `ok.desktop` before changing/launching it. This
preserves representative public filtering while retiring the separate ranking
permutation suite; it is not a repackaging of that suite's scoring scenarios.

## Primary owners and explicit tradeoffs

| Behavior | Retained primary owners | Retired coverage / limitation |
| --- | --- | --- |
| Application search, settings and launch | `test-native-application.py`: actual Quickshell input → search/JSONL → actual daemon on a private bus, failed storage then durable retry, failed launch then explicit retry. Native `tests/session` retains target revisions, receipts, placement, cancellation and ownership/restart. Qt Actions retains Close observation, reopened-panel fencing and owned/malformed status recovery; Settings retains target-scoped feedback. | Mock launch-result/presentation permutations, detail-page matrices, exact rank scores and most resource presentation checks. The native journey does not establish live systemd/compositor behavior. |
| Shared UI interaction | `tst_field_interaction`, `tst_action_control`, chooser keyboard/memory, surface actions and sensitive-domain workflows retain text save/discard/Tab, arrows, deferred/live sliders, disabled/accessibility activation, command/modal focus and value-free restoration. | Caret paint, removal/availability permutations, model internals, per-widget geometry and repeated consumer navigation. No claim of exhaustive pointer/touch/RTL/IME coverage. |
| Clipboard privacy, edits and paste | Qt private-read, pin-versus-paste and Recovery journeys retain draft/lease failure and retry, publication failure, reopened-session handshakes and no replay. Native `tests/api`, `tests/client`, actions/session, capture and settings tests retain real validation, wipe fences, revision-bound cursors, single-use paste, unsafe content and durable privacy. | Direct client-family correlation and cached projection replay; frontend paging and per-state pin-button matrices. No native privacy or publication test is removed based on mocked UI evidence. |
| Wi-Fi credentials and operations | Qt Operations/Prompt/Casting/Portal/IP fields retain saved activation, cancellation, secret timeout/foreign replies, QR privacy, explicit storage choices, portal ownership/no-replay and DNS/native buffer checks. Native SecretAgent callbacks, lifecycle, retention/confirmation, credential migration/writer, activation, forget and forwarding tests remain. Independent QR vectors, SVG non-exposure and typed private-error checks remain. | Device/reason labels, hotspot representation, volatile delta classification, scan-spacing/cache rotation details, duplicate profile-matching assertions and frontend recovery/schema permutations. Private native workflows remain distinct from mocked Qt tests. |
| Bluetooth pairing and effects | Qt pairing identity, close-time clearing, compact prompts and adapter partial-success/retry. Native pairing/OBEX, adapter batches, operation outcomes, startup recovery, helper authorization, opaque endpoint/serial routing, Fast Pair crypto/wire vectors and persistence. | RSSI/battery cache presentation, disconnect labels, profile metadata and generic client/subscription projection repetitions. Actual authorization, cancellation, crypto and path-confinement vectors stay. |
| Displays, battery and sleep | Qt display trial/token/draft, last-output, mirror staging and close-revert journeys; battery critical protection, paired sleep saves/retry, intent-only cancellation, no replay and degraded-telemetry release. Native display layout/focus/docking/mirroring tests, battery authorization/readback/restoration, sleep lock/session/inhibition and critical-policy tests remain. | Frontend reply-table permutations and sleep mock suite, layout math/presentation matrices, history/forecast arithmetic and linked-slider geometry. Physical hardware acceptance remains separate. |
| Notifications and Activity | Native API query/mutation tests, history persistence/revision fences, real notification bus signals, redesign deletion/policy/timeline tests, calendar parser and local-day service tests. Qt confirmed deletion, atomic windows, stale pages and reused-request/draft ownership; Activity day membership/navigation. | Duplicate center/query projections, standalone period/cursor bounds permutations, expiry close-signal repetition and presentation matrices. Not every midnight/read-pagination permutation is retained. |
| Locations and time | Native private-bus authorization/provenance, cancellation, VPN/network/owner fences, stale/malformed fixes, persistence/uncertain writes, protected Home, legacy migration and timezone DST/reconnect tests. Qt manual acknowledgement, protected removal and live clock offsets. | Astronomy/weather normalization and passive estimates, same-zone/diagnostic/revision permutations and most picker presentation/race combinations. Invalid/future/unresolved evidence and invalid-place validation remain. |
| Resource telemetry and media | Native aggregate attribution/ownership, windowless publication, bounded disk work, history clipping/persistence/shutdown, audio readback/failure and private PipeWire test; media unsafe-source/SSRF/download/late-result tests. Qt representative audio/tray and compact media control guards. | GPU/socket/procfs/cgroup arithmetic permutations, extra disk-walk checks, MPRIS label/selection projections, OSD LED readings, artwork fallback geometry and color matrices. Resource-estimate and selection-order detail has less direct coverage. |
| Framework and protocols | Actual JSONL/D-Bus routing, deadlines, quotas, admission, terminal ownership, cancellation, isolation, transport/wire emission, bounded file I/O, atomic writes and Hyprland target/no-replay/security tests. All five daemon contracts, generated JS validation/isolation and independent IP vectors remain. | Standalone envelope/forwarding/export-layout repetitions, discovery-order/resume-stop and work-area math details. The transport safety owners are not replaced by UI mocks. |
| Updates, builds and cache cleanup | Native worker/manifest/source/transaction/vendor trust, rollback, cancellation, locking and real publication/consumer tests. Readiness compatibility/hash/path vectors remain. Cache tests retain root refusal, unsafe paths/symlinks, locks, active processes, tracked/source data and actual cleanup. Local-build CLI plus graph/source-integrity tests remain. | Status/freshness projections, unchanged-release optimizations, scheduling/source-shape repetitions, cache ordering/discovery variants and low-level snapshot/preflight repeats. No support promise or production compatibility branch was removed. |
| Tooling | Actual catalog CLI routing/rejection, generator freshness and unsafe IDs, profiler failure/stale publication/descendant cleanup, and quality gate regression/evidence checks. | New-catalog metadata variants, help/floating/clipboard CLI permutations, profiler parser details and repeated quality-fixture option/error cases. Threshold values and gate implementations are untouched. |

Production behavior is unchanged. Rust source edits outside test-only files remove
`#[cfg(test)]` modules/declarations and their imports, not runtime code. Empty test
modules/helpers, unused QML components/imports, three orphan producer fixtures and
their generation/copy hooks are removed. Nix checks for deleted JS suites are
removed with their source; no surviving suite is excluded. Active coverage docs
and Lens entrypoints now reference retained owners rather than deleted tests.
Historical dated reviews remain historical, not current coverage promises.

## Validation and fault injection

- All seven daemon/framework suites pass: **483 primary passes, 11 existing
  ignores**, excluding repeated child-process executions. `cargo fmt` and
  `cargo clippy --workspace --all-features --all-targets --locked -- -D warnings`
  pass in the corresponding development environments. Bluetooth uses Bar's
  environment for the installed native development dependencies; Update uses
  the framework environment. Initial wrong-environment build attempts were
  corrected, not counted as passing validation.
- Full Qt: **150 passed, 0 failed, 1 existing renderer skip**: 78 executed behavior
  cases plus 72 lifecycle hooks. The baseline was 380/0/1: 274 behaviors plus
  106 hooks. All 79 retained registrations, including the skip, remain counted.
- All **72 retained Python methods** pass, including the native journey. The
  surface CLI uses the exact current Nix-emitted shell script with controlled
  command fixtures; this is not a claim that its full dependency closure built.
- Strict QML lint, native-journey lint, both Quickshell runtime smoke programs,
  generated JavaScript contracts, daemon boundaries, IP vectors and TypeScript
  freshness pass. Freshly built producer binaries match all five API fixtures and
  every retained event/reply fixture (`bash tests/generate-producer-fixtures.sh check`).
  The four native search tests pass.
- All four portal-launcher tests pass in a disposable source copy after offline
  lock resolution. The original portal lock already rejects `--locked`; it is
  deliberately unchanged. This does not claim the original locked build works.
- Sandboxed Nix checks **nativeApplication, generatedContracts, ipValidation,
  daemonBoundary and typescript** build successfully. Building the native journey
  exposed a fixture problem: the packaged daemon wrapper prepends real launchers
  to PATH. The check now explicitly uses the packaged ELF
  (`.app-daemon-wrapped`) with the runner's controlled launcher PATH. This tests
  actual packaged daemon code, not host uwsm/systemd or the wrapper's runtime PATH.
  No assertion or production launcher policy was weakened.
- An initial broader Nix check batch exceeded its time budget while rebuilding
  dependencies. Full `flake check`, packaged surface-CLI/material-color closure,
  numerical coverage gates and VM/live-hardware acceptance are **not claimed**.

Five deliberately broken implementations were tested in disposable copies. Healthy
controls passed first; every mutation produced an executed assertion failure,
not a compilation failure:

| Injected fault | Retained test that rejects it |
| --- | --- |
| Drop actual application settings writes | Real application journey, settings retry stage and independent durable-file oracle |
| Hand off/dismiss after failed launch | Real application journey, failed-launch stage |
| Permit replacing a symlink destination | Framework `bounded_reads_reject_large_nonregular_and_symlinked_files` |
| Claim another owner's operation | Framework `admission_and_terminal_claim_are_owner_scoped` |
| Invert the no-save credential policy | NM `retention_is_per_secret_and_no_save_cannot_silently_persist` |

The last three are intentionally focused native boundary tests, not represented
as end-to-end UI journeys. These probes demonstrate specific retained protections,
not a comprehensive mutation score. All copied mutations were restored; live
production files were never mutated.

## Reproduce the inventory

Collect current `cargo test --workspace --all-features --lib --tests --bins
--locked -- --list` output from each daemon/framework repository in its development
environment as `<repository>-discovery.log`, and a complete Qt run. From Shelllist:

```sh
python3 tests/count-ecosystem-tests.py \
  --rust-logs target/test-reduction-owners --rust-log-suffix discovery \
  --qml-log target/test-reduction-owners/qml-final.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'

python3 tests/count-ecosystem-tests.py \
  --snapshot target/test-reduction-owners/baseline.tar.gz \
  --rust-logs target/test-reduction-owners --rust-log-suffix before \
  --qml-log target/test-reduction-owners/qml-before.log \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
```

The result is an acceptance snapshot, not a cap on future useful regression tests.
