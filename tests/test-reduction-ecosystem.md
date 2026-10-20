# Ecosystem test review — partial reduction, target not met

## Decision

**Do not accept this as completion of the requested ≥33% reduction.** This pass
removes 35 registered cases/suites from the measured inventory: **1,029 → 994
(3.40%)**. Its strict 67% target is **689**, not a rounded-up value. Another
**305** removals would be required even within this inventory.

The review found safe duplicates and implementation-specific assertions, but has
not established enough higher-level replacement coverage to justify that further
cut. It is not a proof that no further reductions are possible. In particular,
Shelllist's native Qt tests usually inject daemon responses: they exercise the UI
and frontend controllers, **not the daemon implementations**. Passing those tests
cannot justify deleting native credential, authorization, persistence or hardware
adapter tests. Conversely, private-bus daemon tests do not exercise Qt input,
drafts, focus, confirmation or frontend request ownership.

Older reduction checkpoints describe different source trees. Some rounded their
67% limits upward; neither those counts nor that rounding satisfy this request.

## Fresh baseline and accounting

Baseline revisions, with incoming edits included:

- shelllist `8989e20`; app-daemon `f6452fc`; bar-daemon `709156e`
- bt-daemon `54cf57a`; clip-daemon `c78960b`; nm-daemon `b7efa39`
- update-daemon `dbb6a33`; daemon-framework `8084fcd`

| Repository | Before | After | Removed |
| --- | ---: | ---: | ---: |
| shelllist | 364 | 348 | 16 |
| app-daemon | 62 | 60 | 2 |
| bar-daemon | 206 | 205 | 1 |
| bt-daemon | 60 | 60 | 0 |
| clip-daemon | 41 | 41 | 0 |
| nm-daemon | 106 | 106 | 0 |
| update-daemon | 112 | 112 | 0 |
| daemon-framework | 78 | 62 | 16 |
| **Measured suite inventory** | **1,029** | **994** | **35** |

Count Rust libtest entries, Python `test_*` methods (including hyphenated test
filenames), Qt executed data rows plus the existing renderer skip, each behavioral
JavaScript script once, and the five daemon contract suites once. Include existing
ignored/feature-enabled Rust tests; exclude Qt lifecycle hooks, helper subprocess
reruns, assertions, Python subtests, and repeated package/CI executions. The copied
search crate is counted at its source owner, not again under clip-daemon/vendor.
Rust names are qualified by test binary to avoid merging equal names.

Shelllist's baseline components are 296 Qt + 38 Python + 8 Rust + 17 JavaScript
suites + 5 contracts; final components are 282 + 37 + 8 + 16 + 5. Its older mixed
assertion-site counter also omits the hyphenated Python filenames; it is not the
counter used for this table. No counter or runner discovery rules were changed.

This is **not an exhaustive count of every external acceptance command**. Separate
NixOS VM matrices, the update launcher Nix check, Ringboard/desktop acceptance
scripts, packaging/static checks, benchmarks without libtest registration and
manual captures remain unchanged and outside this table. Including unchanged
additional tests only reduces the percentage removed; there is no claim that the
whole-codebase target is met under either scope.

## Deletions and retained owners

| Removed | Retained evidence / tradeoff |
| --- | --- |
| Framework's 16 copied cache tests | The byte-identical policy's owning suite is `update-daemon/scripts/test_trim_build_cache.py`, alongside the scheduler's real dry-run/cleanup workflow. Literal glob-path accounting is retained there. Git fsmonitor suppression is now exercised with a real configured executable that must not run, rather than asserting Git argv. This is duplicate test ownership, not removal of cache safety requirements. |
| App target-revision helper matrix | `tests/session/extra.rs` changes launch metadata through the real daemon, rejects stale actions, and verifies row-scoped actions amid unrelated activity. Individual hash-input/order permutations lose direct coverage; the public admission journey remains. |
| App GPU allocation comparison | Retain counter parsing, aggregation, identity/rebaseline and resume behavior. Comparing a streaming iterator against collecting that same iterator freezes an implementation choice, not an end-user resource contract. No performance-equivalence claim. |
| Bar at-home projection replay | Retain `current_is_single_populated_and_replaced_not_appended`, invalid-location rejection, durable catalog mutations, location API revision/protected-role guards, and native Time & Weather manual/automatic workflows. No UI-mock-as-Rust-coverage claim. |
| Six exact popover-height rows | Keep native window smoke, work-area recovery and actual chooser navigation. Exact cap/centering formula and every emergency size are no longer independently asserted. |
| Two terminal-artwork pixel rows | Keep acknowledged workspace activation and keyboard routing. Chevron/frame pixels, exact width, boldness and palette mapping are no longer requirements imposed by tests. |
| Two quarter-avatar pin-badge rows | Keep actual avatar pin/unpin, native order, failure/no-optimism, keyboard actions and guard matrix. Exact badge fraction/placement/colors and its separate hit region lose direct coverage. |
| Two Time & Weather header geometry rows; one repeated light-theme picker row | Keep normal and collapsed picker journeys, manual/automatic acknowledgement, stale searches/replies, removal identity and protected roles. Do not freeze exact 56/32-pixel buttons or repeat the same interaction by palette. |
| Repeated Qt generated-contract matrix | `check-generated-contracts.js` executes the same generated validator and full fixture mutations. Qt retains shared-runtime schema isolation; native consumer tests retain real request/reply handling. |
| Clipboard duplicate-terminal helper script | Duplicate terminal delivery now runs through the native pin workflow's backend while a second operation is pending, proving it cannot retire that newer operation. The deleted script's sole Nix check is removed, not replaced with a success stub. |
| Surface-catalog literal order/loading/shortcut table | Retain generator rejection/freshness tests, CLI routing, and surface activation tests. Eager-loading choices, catalog ordering and default shortcut literals should not become unnecessary compatibility promises. |

No tests were renamed out of discovery, newly ignored, or hidden behind features.
No old tests were turned into helper functions called by a mega-test. Apart from
the two cache safety additions and duplicate-terminal injection into an existing
native workflow, retained scenarios were not repacked. Production behavior,
dependencies, coverage thresholds, protocol fixtures and the incoming user edits
are unchanged. The deleted-file gate and documentation references are cleaned up.

## Boundaries that still need higher-level evidence before larger cuts

- **Bluetooth:** retain private-bus recovery, actual BlueZ signal sender checks,
  typed PipeWire PODs, RSSI/Polkit identity, secret clearing, authenticated frame
  vectors, timeout/backpressure and per-device cancellation. The UI's fake backend
  cannot detect a broken native decoder or wrong D-Bus signature.
- **Clipboard:** retain real Ringboard IPC framing, content identity, unsafe-file
  refusal, capture/privacy fencing, commit cancellation and clipboard publication
  failure. JSONL request churn and fake-engine API tests alone do not cover these.
- **NetworkManager:** retain exported SecretAgent callbacks, one-shot ownership,
  deferred-save confirmation races, credential-writer preservation, private-profile
  identity, firewall boundaries, portal no-replay and rollback. Version-policy
  tests enforce an explicit safety allowlist, not incidental version presentation.
- **Update worker:** most Rust tests already exercise workflows, subprocesses or
  real filesystem boundaries. Preserve transaction preimages, interrupted recovery,
  untrusted Git trees, immutable inputs, vendor integrity and safe cache retention.
- **Framework:** private-bus transport tests cannot alone replace framing limits,
  partial-read cancellation, peer/socket ownership, retained-result expiry or
  filesystem confinement. Preserve local reference vectors and deterministic races.

A next phase should add a small number of real UI→JSONL→daemon journeys on private
buses and disposable filesystem/native-service fixtures, then map removable local
scenarios to those executed paths. Do not merely rename the current mocked Qt
suite “end-to-end.” For every candidate deletion, record the retained owner and
explicit uncovered edge cases; reject arbitrary per-repository quotas.

## Validation and limitations

- Fresh baseline Qt: **409 passed, 0 failed, 1 existing skip**; final Qt:
  **393 passed, 0 failed, 1 identical skip**. Behavioral cases: 296 → 282;
  hooks: 114 → 112. Final strict QML lint and both native runtime smokes pass.
- App: **49 primary tests passed, 3 existing ignored entries**; all 15 private-bus
  integration tests passed. The internal helper's child rerun is not another test.
- Bar: **195 passed, 3 existing ignored entries** (PipeWire, native idle and an
  internal child fixture). No isolated hardware/native-fixture acceptance claimed.
- App and Bar package formatting and strict Clippy pass.
- Update Python: **36 passed**. Surface catalog: **6 passed**. Generated JavaScript
  contracts pass. Surface CLI: **5 passed against the installed executable with
  fake desktop entrypoints**; this is not a current-source packaged CLI build.
- Other Rust suites were inventoried but not rerun after this test-only change;
  their source is unchanged. Full sibling/Nix/VM, live compositor/hardware and
  coverage/mutation runs were not performed. Bluetooth's own offline dev shell
  was blocked on a WirePlumber dependency; discovery used Bar's available shell.
  Update has no default dev shell; discovery used the framework shell.
- Incoming Shelllist build-input edits and Bar location documentation/flake edits
  are preserved. Nix-created lockfile changes were reverted; no dependency pins
  are included in this patch.

Local evidence is under `target/test-reduction-ecosystem/`: `baseline.tar.gz`,
source inventories, matching Qt logs, Cargo discovery/execution/lint logs,
Python logs, `summarize.py` and `inventory.json` with every removed case. Recompute:

```sh
python3 target/test-reduction-ecosystem/summarize.py
# Runtime validation, using an available matching development shell:
QML_XHR_ALLOW_FILE_READ=1 tests/run-qml-tests.sh
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
# app-daemon / bar-daemon respectively:
cargo test --locked --all-features --lib --tests
cargo test --locked --all-features --lib --tests --bins
# update-daemon:
python3 -B -m unittest discover -s scripts -p 'test_*.py' -v
```

The evidence archive includes the incoming worktree, not just HEAD. These counts
are a review checkpoint, not a permanent cap on new regression tests.
