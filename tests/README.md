# Test scope

Prefer end-to-end user journeys and public-boundary integration tests. Keep local
tests for unique failure modes that those flows cannot reasonably exercise; do
not mirror implementation tables or freeze visual choices unnecessarily.

The [ownership reduction](test-reduction-owners.md) reaches the strict target:
**988 → 661 registered cases/suites, 327 removed (33.10%)**. The counter and
discovery rules are unchanged. That review records primary owners, deliberately
retired coverage and exact before/after accounting. The [native-journey pass](test-reduction-vertical.md),
[ecosystem review](test-reduction-ecosystem.md) and checkpoints below are historical;
do not reuse their totals as the current baseline.

## Rust development tooling

See [`tools/xtask/README.md`](../tools/xtask/README.md). `cargo xtask` owns surface
catalog generation, build-input auditing, conservative cache trimming and contract
parity. `cargo xtask contracts --nix` runs the producers' own serde fixture tests
and builds, then compares their offline exports with the frontend fixtures.
The old jq/shell contract gates are removed, not retained as weaker parallel checks.
`cargo xtask check-daemon-boundary` and `check-ip-validation` run the migrated
regression vectors against actual QML objects in Qt; Nix's full QML suite includes
them. Neither check starts a real daemon or changes hardware.

## Native Unix socket migration

The current [stream/recovery contract](../contracts/unix-jsonl-stream-recovery.md)
records staged progress and remaining gates. The Bluetooth
ignored test launches `tests/e2e/unix-jsonl.qml` with real Socket/Process plugins,
a private bus/runtime and an in-memory producer. It covers native UTF-8/large-line
parsing, bounded blocked writes, no replay, service recreation and comparative
RPC latency/process-group memory. Do not launch it against live services.
`tests/qml/tst_daemon_socket.qml` separately owns deterministic adapter regressions;
its mock transport is not native backpressure or performance evidence.

Reproduce Bluetooth from Shelllist using its native build dependencies plus the
frontend's matching Quickshell (the Shelllist shell alone lacks `dbus-1.pc`):

```sh
export SHELLLIST_SOURCE="$PWD"
export SHELLLIST_QUICKSHELL="$(nix develop . --no-write-lock-file --command bash -c 'command -v quickshell')"
export BT_DAEMON_BIN="$PWD/../bt-daemon/target/debug/bt-daemon"
export SOCKET_PROBE_REPORT="$(mktemp -d)/bt-socket.json"
nix develop ../bt-daemon --no-write-lock-file --command bash -c '
  set -e
  export PATH="$(dirname "$SHELLLIST_QUICKSHELL"):$PATH"
  cd ../bt-daemon
  cargo build --locked --bin bt-daemon
  cargo test --locked --lib unix_socket_acceptance_probe -- --ignored --nocapture
'
```

`tst_snapshot_cursor.qml` and `tst_bluetooth_stream_recovery.qml` separately cover
full-state ordering through actual Qt, with producer-owned fixtures and shared
session routing. They are not additional native backpressure/performance probes.

NM's `daemon::socket::tests` compares actual socket and D-Bus dispatch with a
scripted NetworkManager, fences owners, cancels a private in-flight connect on
disconnect, and recreates the listener without replay. The separately ignored
native probe launches `tests/e2e/nm-unix-jsonl.qml` through real Quickshell 0.3.0:
production shared-session routing, eight reads, an authoritative network baseline,
and collection renewal without retiring the secret observer. From Shelllist:

```sh
nix develop . --no-write-lock-file --command bash -c '
  set -e
  export SHELLLIST_SOURCE="$PWD"
  cd ../nm-daemon
  cargo test --locked --lib native_quickshell_nm_socket_acceptance -- --ignored --nocapture
'
```

The harness supplies a private 0700 runtime, private session bus, unavailable host
system bus, scripted backend and bounded child/log lifetime. Do not launch these
QML fixtures standalone against live services. Neither listener recreation nor
this native smoke test establishes OS-process-crash, release/mixed-load, maximum
NM payload or hardware acceptance. `SHELLLIST_NM_SOCKET=1` is opt-in only and needs
a matching already-running daemon; socket activation/default switching is deferred.

App's `tests/session/socket.rs` uses the actual private daemon OS process: socket/
D-Bus parity, owned cancellation/status/event visibility, disconnect with unread
acceptance, release and SIGKILL/restart during a fake handoff. No real application
is launched. The separate native Quickshell probe exercises production shared
routing, eight catalog reads and subscription renewal:

```sh
# From Shelllist; use app's build dependencies, not the frontend Cargo environment.
export SHELLLIST_SOURCE="$PWD"
export SHELLLIST_QUICKSHELL="$(nix develop . --no-write-lock-file --command bash -c 'command -v quickshell')"
nix develop ../app-daemon --no-write-lock-file --command bash -c '
  set -e
  cd ../app-daemon
  cargo test --locked --test session socket::native_quickshell_app_socket_acceptance -- --ignored --nocapture
'
```

The harness clears the native child's environment, uses private HOME/runtime and
nonexistent bus addresses, and selects `SHELLLIST_APP_SOCKET=1`. Do not run the QML
fixture standalone against live services. The app listener must already run for
normal opt-in use; cold-start/default switching is not implemented by this stage.
The 405-pass Qt checkpoint (one existing renderer skip) separately covers query/
invalidation barriers and atomic operation-revision consumption, including quiet
terminal status recovery and old-producer rejection. Neither suite establishes
maximum payload, matched release performance or sustained-load acceptance.

### Bar atomic ordering checkpoint

Producer `8f30caa` adds per-domain atomic publication metadata and independently
captured post-effect observations. `tst_bar_publication.qml` and the bar recovery,
display, battery, theme, notification and location interaction suites cover stale/
duplicate/malformed records, rollover, quiet-loss reads, isolated renewal, pending
work and drafts. A deferred display rollback targets its acknowledgement's trial
ID, never a different trial observed by a later read; connection loss clears that
intent. Location receipts wait for current activity state before selecting a row.

Validation: **418 Qt passes / one existing renderer skip**, strict QML lint and
producer-generated contracts; **221 debug library passes / two normally ignored**
and all-target Clippy. The sibling-source release package ran **223 library,
30 update-worker and two isolated native passes**, including ignored cases.
`barDaemonContract`, `qmlTests`, `materialGallery` and `buildInputs` are the matched
Nix gates. The gallery uses the **bridge**, not a bar socket. The bar socket flag
and private shared-Quickshell socket probe remain next-stage work; these results
are not installed-session, sustained-load, maximum-payload, release-performance
or OS-process-crash acceptance. No live service or hardware changes were made.

## Panel standardization acceptance

`docs/panel-ui-standardization.md` records current roles, the twelve-panel matrix,
exceptions and separate source/offscreen/live evidence. Those are historical
acceptance results, not a claim that every visual matrix remains automated.
Shared field/command tests retain interaction and native identity. Standalone
long-diagnostic geometry, `PanelRoles` and per-family/Weather geometry matrices
were removed across pruning passes. Historical manual all-panel captures record
fixed status bounds and representative real-consumer error transitions; those
presentation choices are not mandatory contributor requirements. See [current convergence evidence](../docs/shared-panel-ui-convergence.md);
pruning checkpoints below describe historical source snapshots, not this run.
The explicit manual capture fixtures cover panels, dense forms and display safety
states. Generate the local comparison gallery with `tests/build-panel-gallery.py`;
use `tests/review-panel-ui.py --base <ref>` as an advisory PR drift review, not a
blanket ban on numeric domain geometry. Neither freezes screenshots as goldens.

## Retained coverage

`tests/test-native-application.py` is the primary application search/settings/
launch journey: real Quickshell input, search and JSONL processes, a private bus,
actual daemon persistence, storage failure and explicit launch retry. It runs in
`checks.nativeApplication`; see the [runner command and limits](test-reduction-vertical.md).
Adversarial frontend ownership/reply tests remain separate; they deliberately use
recording transports and are not daemon implementation coverage.

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG plugins, timezone data and the same
Fontconfig configuration as the application. Both QML runner scripts use the same
offscreen/software, UTC setup. Refresh an existing development shell after changing
`flake.nix`; missing application fonts can invalidate layout observations.

- Shared field/chooser owners retain text save/discard/Tab, native arrows,
  deferred/live slider transactions, command navigation, modal containment and
  readiness-based restoration without unsaved values. Sensitive targets remain
  non-restorable. Availability/removal and caret-paint permutations are retired.
- Application tests retain close observation, old-operation panel fencing,
  owned status recovery and target-scoped settings feedback, alongside the real
  native journey. Resource/parser/presentation permutations are reduced.
- Display journeys retain last-output protection, draft/daemon-token ownership,
  mirror staging and explicit-close reversion without replay. Native daemon tests
  retain docking, hardware identity, persistence, rollback and confirmation safety.
- Bluetooth retains close-time secret clearing, pairing identity and partial
  adapter acknowledgement/retry. Clipboard retains private reads, pin-versus-paste,
  failed edit leases/drafts and publication/reopened-session paste handshakes.
- Wi-Fi retains saved activation, cancellation, credential timeout, foreign secret
  replies, QR privacy, explicit storage choices, portal claims/no-replay, sharing
  fences and native DNS/buffer validation. Native SecretAgent/security tests remain.
- Battery retains independent critical protection, sleep-pair save/retry, intent-only
  cancellation, no replay and degraded-telemetry release. Native safety tests own
  authorization, lock confirmation, unsafe settings and restoration.
- Notifications retain confirmed deletion, atomic timeline publication, stale pages
  and request/draft ownership. Native API/history tests own query and persistence
  behavior. Time/Weather retains acknowledged manual selection, protected removal
  and live clock offsets; Activity retains native day membership/navigation.
- Audio and tray retain representative acknowledged/identity-guarded commands.
  Media retains compact transport/capability guards and the existing RHI artwork
  check (still skipped under the software renderer). Layout/theme/fallback matrices
  are intentionally reduced.
- Shared daemon bridge/session and Bar recovery tests retain drain/exit behavior,
  ready-session attachment, isolation and stale-generation fencing. Native framework
  tests own transport deadlines, quotas, cancellation, routing and owner loss.
- JavaScript retains generated producer/consumer runtime contracts. Daemon boundary
  and IP-validation vectors now execute in Qt, driven by Rust xtask checks.
  All five typed producer contract checks plus frontend parity, generated
  source freshness, QML lint and runtime smoke remain. Direct model, telemetry,
  history, color and per-controller JavaScript suites are retired.

Expected negative-test application error logs are distinct from QML engine
warnings and remain allowed. Offscreen tests do not replace live compositor,
hardware, IME or screen-reader acceptance.

## Previous pruning checkpoint — baseline `c4bd285`

**441 → 295 inventory units: 146 removed (33.11%), 66.89% retained.**
The unchanged counter gives `round(441 × 0.67) = 295`. Actual reductions are
143 Qt cases/data rows and three redundant/geometry-specific JavaScript assertion
sites; no filtering, hidden tests, scenario packing or new skips. Production,
fixtures, runners, the counter and all five daemon contract checks are unchanged.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 71 | 68 |
| Qt behavioral cases/data rows, including existing skip | 355 | 212 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Total** | **441** | **295** |

Full Qt: **315 passes, zero failures, one existing renderer skip** (211 executed
behaviors + 104 excluded lifecycle hooks). Fifty-two suites remain. This mixed
inventory is not coverage; 295 is not a cap on future regression tests.
See [decisions, retained owners, validation and explicit gaps](test-pruning-current.md).
Strict lint, all 17 JavaScript suites, source-relative imports, Python, Rust search
and runtime smoke pass. Four portal tests pass with an isolated temporary offline
lock; the unchanged repository lock cannot run locked. Full current-source
`local-build check . --offline --keep-going` is blocked by an unrelated untracked
review file in sibling `daemon-framework`, so daemon contract gates/full release
validation were not rerun. Matching evidence: `target/test-pruning-c4bd285/`.
The preceding **618 → 414** review is historical: `git show c4bd285:tests/test-pruning-current.md`.

## Historical ownership regressions

The [ownership refactor](../docs/ownership-refactor.md) adds 14 focused native
cases after pruning: notification completion fencing, chooser restoration
fallbacks/readiness, and clipboard captured-target/paste ownership. At that checkpoint,
the full Qt run had **606 passes, zero failures, one existing renderer skip** (482 executed
behaviors + 124 lifecycle hooks). Established inventory: **555**, including that
skip. Lint, all 17 JavaScript checks and runtime smoke pass at each refactor step.
The pruning figures below remain historical evidence, not a test-count cap.

## Previous pruning checkpoint — baseline c6451f8 + incoming work

**808 → 541 inventory units: 267 removed (33.04%), 66.96% retained.**
`round(808 × 0.67) = 541`, using the unchanged established inventory counter.
The baseline includes the preceding Lens refactor and all other incoming edits.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 57 | 57 |
| QML behavioral cases/data rows, including one existing skip | 736 | 469 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **808** | **541** |

All reductions are actual Qt cases/data rows across 23 files. Contract matrices
retain live request shapes and sample failures by state owner instead of crossing
every method with every error/reconnect condition. Compatibility-only routes,
repeated palette/layout/wording checks and duplicate per-surface input routes are
removed. Shared native editing, confirmation, ownership, stale replies, secret
handling, partial acknowledgement and no-replay tests remain. No production code,
runner, counter, build check, fixture or discovery change; no new skips.

Validation: **592 Qt passes, zero failures, one unchanged renderer skip**
(468 executed behaviors + 124 lifecycle hooks), strict lint, all 17 JavaScript
checks, two Python tests, four Rust search tests and native smoke pass. The four
portal-launcher Rust tests are blocked by an unchanged lockfile/dependency mismatch;
no lockfile was updated. Five daemon contracts and full Nix/hardware gates were
not rerun. The mixed inventory is not coverage, and retained shared tests do not
prove all removed endpoint/presentation permutations.

Historical decisions: `git show 46407b7:tests/test-pruning-current.md`.
Matching evidence is in `target/test-pruning-c6451f8/`. Earlier counts below are
historical; this target is not a cap on future regression tests.

## Previous pruning checkpoint — baseline aefcf52

Baseline includes the incoming uncommitted changes, not an older historical
checkpoint. **430 → 288 inventory units: 142 removed (33.02%), 66.98% retained.**
`round(430 × 0.67) = 288` under the unchanged established counter.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion sites | 76 | 57 |
| QML behavioral cases/data rows, including one existing skip | 339 | 216 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **430** | **288** |

The reductions are 123 actual Qt cases and 19 JavaScript assertion sites, mostly
repeated data rows, UI implementation/geometry checks, obsolete inline-tray tests
and transport scenarios duplicated by native Qt tests. No counter, discovery,
build-check or production changes; no new skips or hidden tests. Essential shared
editing, acknowledgement, destructive confirmation, stale ownership, secrets,
retry and no-replay workflows remain. The mixed inventory is not branch coverage.

Validation: **311 Qt passes, zero failures, one unchanged renderer skip**
(215 executed behaviors + 96 lifecycle hooks); all 16 behavioral JavaScript
scripts plus source-tree imports, eight Rust tests, two Python tests, QML lint
and native runtime smoke pass. The five retained daemon contract suites and full
Nix/hardware/RHI gates were not rerun.

Earlier decisions are retained in Git history. Matching baseline/final sources,
logs and inventories are in ignored `target/test-pruning-aefcf52/`. The older checkpoints below are historical, not
current coverage promises. This target is not a permanent cap on useful tests.

## Previous working-tree pruning checkpoint

Baseline included the incoming uncommitted changes at that earlier request.
**365 → 245 inventory units: 120 removed (32.88%), 67.12% retained.**
This is the nearest-integer 67% target under the existing mixed counter.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 55 | 55 |
| QML behavioral cases, including data rows and one existing skip | 295 | 175 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **365** | **245** |

All 120 reductions are actual Qt case removals, not renames, new skips, assertion
repacking or discovery exclusions. Five redundant suites and their unused
fixtures were removed; Lens loses only the deleted notification-actions
entrypoint. A few unique safety assertions moved into retained workflows.
Production code, the counter, runner and JavaScript/native tests were not changed
by this pass. Existing unrelated worktree and staged changes were left intact.

Validation: **258 Qt passes, zero failures, one existing renderer skip**
(174 executed behaviors + 84 lifecycle hooks), all 16 behavioral JavaScript
scripts, eight Rust tests, two Python tests, QML lint and native runtime smoke.
The five daemon contract suites remain unchanged and were not rerun; no full Nix
or hardware/RHI gate is claimed. This mixed count is not a coverage percentage.

The earlier decisions are retained in Git history. Matching historical baseline
and final logs are in ignored `target/test-pruning-current/` (`before-qml.log`,
`final-qml.log`, `before.json`, `final-inventory.json`). Earlier files in that
artifact directory describe previous passes and must not be mixed with these.
This target is a checkpoint, not a permanent cap on useful regression tests.

## Previous pruning checkpoint — 2026-10-07

Baseline: refactor commit `416bd9e`, with unrelated incoming changes preserved.
Nearest-integer 67% target: **464 → 311 inventory units** (**32.97% removed;
67.03% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 90 | 54 |
| QML behavioral cases, including data rows and one existing skip | 359 | 242 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **464** | **311** |

This established mixed inventory is **not independent scenarios or a coverage
percentage**. There are genuinely **117 fewer Qt cases**; the 36 fewer JavaScript
sites mostly consolidate related checks into labeled tables, retaining numeric
validation/interval cases while removing presentation assertions covered by Qt.
No tests were newly skipped, hidden in renamed helpers or excluded from discovery.
All suites and Lens entrypoints remain. Native transaction, domain safety,
protocol, retry and no-replay coverage takes priority over visual matrices,
per-wrapper geometry, exact icon tables and duplicate happy-path workflows.

Final validation: **331 Qt passes, zero failures, one unchanged renderer skip**
(241 executed behaviors + 90 hooks), all 16 JavaScript scripts, strict lint,
runtime smoke, TypeScript generation/typechecking, eight Rust and two Python tests
pass. All five daemon contracts remain unchanged but were not executed; no full
Nix gate was run. An RHI probe failed pixel checks on this host and is not claimed
as acceptance. See the [review](../docs/reviews/test-pruning-2026-10-07.md) for
explicit coverage gaps, the baseline renderer evidence and reproduction commands.
Local artifacts: `target/test-pruning-2026-10-07/`.

The inventory counter still rejects failures, unexpected skips and incomplete
logs. Count the pre-existing software-renderer skip explicitly in both snapshots:

```sh
python3 tests/count-test-inventory.py --qml-log <matching-run.log> \
  --expected-qml-skip 'qmltestrunner::MediaChip::test_artworkReallyClipsRoundedCorners()'
```

The skipped case remains counted but is **not executed coverage**. This explicit
accounting option does not skip anything or change the test runner. Without the
option, skips still fail inventory validation. These counts are not a permanent
cap; add focused regressions for meaningful failures.

## Previous pruning checkpoint — 2026-10-06

Baseline: `8f47572` plus the incoming uncommitted media changes. Nearest-integer
67% target: **314 → 210 inventory units** (**33.12% removed; 66.88% retained**).

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 83 | 47 |
| Executed QML behavioral cases, including data rows | 216 | 148 |
| Rust tests | 8 | 8 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **314** | **210** |

This is the established mixed inventory, **not independent scenarios or a
coverage percentage**. The counter now recognizes line-wrapped daemon-contract
builders, previously undercounting five declarations as three; the same corrected
counter measures both snapshots. Other counting rules are unchanged.

**68 Qt behavioral cases were removed.** The 36-site JavaScript reduction mostly
consolidates repeated validation assertions and related output checks while
retaining their input cases; it is not 36 deleted behaviors. QML runner totals
**286 → 212** include **70 → 64** excluded lifecycle hooks. No tests were skipped
or renamed into undiscovered helpers. Three suites were deleted, and Lens loses
only the two corresponding explicit entrypoints.

Validation: 212 QML passes, all 16 behavioral JavaScript scripts, source-tree
relative imports, strict lint, runtime smoke, generated TypeScript verification,
TypeScript typechecking, eight Rust tests and both Python tests pass. All five
daemon contracts remain unchanged; the full sibling-aware Nix gate and contract
executables were **not rerun**.

Direct per-wrapper visual/size matrices, some happy-path restoration and consumer
wiring checks, exhaustive history schema variants, native slider End, RTL segment
navigation, outside-drop cancellation and standalone animation completion receive
less direct evidence. Essential behavior remains covered, but fewer tests do not
prove identical branch coverage. The historical 2026-10-06 review is retired from the checkout; its decisions
and explicit coverage gaps are summarized above.
Evidence is in ignored `target/test-pruning-2026-10-06/`.

This checkpoint is not a permanent test-count cap. Add focused behavioral
regressions when a meaningful failure is found.

## Historical checkpoints

Retired review records (counts retained for history; files are no longer linked):

- 2026-10-05: 359 → 241
- 2026-10-04: 396 → 265
- 2026-09-27: 298 → 200
- 2026-09-26: 357 → 239

These describe earlier sources and validation, not the current suite. Always
count matching source snapshots and QML logs; the inventory script rejects
incomplete, failing, unexpectedly skipped or duplicate-case logs.
