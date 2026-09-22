# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables, compare helpers against themselves, or freeze visual
choices unless they are an explicit user-facing regression.

## Current pruning inventory

Baseline: Shelllist `d6a339f`. This pass supersedes the previous inventory against
`36e8a95` (available in Git history); sibling daemon repositories are not pruned.

Shelllist has ad-hoc JavaScript checks, QtTest, Rust and Python, not a single
runner-reported test total. Using the **same counting rule as the previous pass**:

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper call sites | 460 | 274 | 186 |
| Executed QML behavioral cases, including data rows | 175 | 148 | 27 |
| Rust test functions | 4 | 4 | 0 |
| Python test methods | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Combined inventory units** | **646** | **433** | **213** |

**32.97% removed; 67.03% retained**, the nearest whole-unit result to 67% of 646
(432.82). These are mixed inventory units, **not 646 independent scenarios** and
not a coverage percentage. In particular, Qt's full total changed from 247 to
220 passes; both include 72 setup/cleanup hooks, which are excluded above.

JavaScript counts line-leading assertion/helper calls once per source site,
including calls inside helpers and loops, not once per invocation. Redundant
assertions within retained scenarios were removed as well as whole scenarios.
Tests were not disabled, renamed out of discovery, or packed into larger
assertions to lower the count. Setup calls remain where later observations
already prove their result; removing an assertion does not remove the action.

As before, infrastructure gates are additional and unpruned: packaging/imports,
module evaluation, generated assets/TypeScript, native lint, performance,
application-resource fixture compatibility and native hypridle readiness.
They are not counted as behavioral cases. The five counted contract suites are
the `*DaemonContract` flake checks. Rust's four tests are in
`rust/shelllist-search/src/lib.rs`; Python's two are in `test_profile_qml.py`.

### Reproduce

Capture each QML log from its matching revision in the declared development
environment, then use the current inventory script from the repository root:

```sh
# Before editing, at d6a339f:
tests/run-qml-tests.sh > /tmp/shelllist-qml-before.log
# After editing:
tests/run-qml-tests.sh > /tmp/shelllist-qml-after.log
python3 tests/count-test-inventory.py --revision d6a339f \
  --qml-log /tmp/shelllist-qml-before.log
python3 tests/count-test-inventory.py --qml-log /tmp/shelllist-qml-after.log
```

The script preserves the previous JavaScript counting expression and rejects
incomplete, failing, skipped or duplicate-case Qt logs. The source revision and
log must match; the log itself does not encode a Git revision.

## Removal decisions and remaining owners

| Removed or reduced | Remaining owner / rationale |
| --- | --- |
| Battery controller status/busy booleans, repeated success returns, legacy alert-policy migration and level-toggle duplicates | `tst_battery_suspend.qml` and `tst_battery_tabs.qml` own user-visible state, acknowledgement, keyboard/accessibility, independent levels and unknown-outcome handling. JS retains autosave races, edited battery identity, global operation exclusion, capability guards, AC/cancellation, command dispatch, failed saves and transport uncertainty. Unavailable-service level fallback and explicit automation resume remain checked. |
| Battery suspend message catalogue and duplicated helper capability checks | Actual suspend controls own displayed messages and inhibition. JS retains invalid threshold boundaries, block-weak filtering and daemon diagnosis versus policy-denial precedence. |
| Battery chart property copies, obsolete helper-absence checks and repeated widths | JS retains invalid samples, discontinuities, signed power areas, charging outliers, zero transitions and duplicate/late observations. Qt retains actual isolated 0/100% rendering, forecast/hover changes, range/live updates, empty history and narrow-card bounds. The repeated Qt power-area calculation case is removed in favor of JS's direct algorithm checks. |
| Application history bookkeeping and formatter/badge catalogues | History tests retain target/range isolation, stale replies, cancellation, paginated catch-up, sliding-window pruning, cursor retention, partial failures, overlap, nonadvancing cursors and frozen native summary windows. Resource tests retain unavailable/null versus measured-zero data, low-confidence warnings, actual canvas gaps and rejection of battery discharge as per-app power. |
| Bar helper OSD snapshots, incidental cycling/visibility choices and duplicate resume inputs | Actual bar OSD tests retain immediate confirmed values, all four failure routes, unrelated-error isolation and reopening during dismissal. Resume tests retain initial/repeated/incremented/reset generations; routing, media progress, update failure visibility and narrow-screen action reachability remain. |
| Bluetooth icon/text/layout matrices, technical-field placement, tab-composition constraints, one-field audio-profile dispatch duplicate and repeated list-filter combinations | Recovery tests retain pairing queue/input/request identity, failed replies, unavailable services, live reconnect, opaque audio keys, apply-then-remember identity, save/transport failures, rename/adapter drafts, global settings and scoped reset. JS retains representative mine/all filtering, display-passkey progress, action validation, scan failure and terminal lifecycle behavior. Shared controls own activation/busy policy. |
| Repeating shared detail layout across eleven page variants | Three representative consumers remain: application resources, Bluetooth adapter and Wi-Fi cards, each resized and hidden/reopened. Shared `DetailLayout` still covers wrapping, hidden children/headings, scrolling and asynchronous loader/footer bounds. Consumer recovery suites and packaged smoke cover other construction paths; this is intentionally not exhaustive per-page visual coverage. |
| Pure Qt anchoring/centering checks, weather hero pixel composition, empty-card construction-only smoke, fixed Time & Weather placement, retired compositor helper names and a repeated geometry row | Retain dynamic layout failure boundaries, real weather clock/keyboard behavior, native work-area changes, fractional/negative-origin geometry and tiny-screen clamping. Icon alignment, exact weather columns and incidental placement are no longer frozen. |
| Clipboard reset-only profiler-gap case | Clipboard recovery and action tests own failed/late saves, visible draft persistence, conflicts/discard, selection, leases, native search and revision-checked deletion. Adapter isolation, asynchronous battery artwork and native solar metadata tests remain. |
| Network-health reason/state traces duplicating a daemon-owned classifier | Retain recommended/suppressed notification policy, strict boolean advice, daemon messages, deduplication and credential-redacted logging. The frontend should not reimplement DHCP/VPN/suspend classification. |
| Display title/picker counts, a duplicate rotated rectangle and helper fingerprint comparisons | All ten Displays Qt cases are untouched, including preview/confirm/revert, pending-close cancellation, topology replacement and reconnection. JS retains exact refresh strings, mixed-DPI/rotation geometry, malformed input, safe finite rectangles, fallback/last-output protection, complete unique connector sets, payload fields and snapping. |

The daemon-boundary/session, Wi-Fi secret/casting/IP, clipboard recovery/action,
notification interaction, shared activation/keyed-model, Rust search and Python
profiler suites are unchanged. No production code, contract fixture, dependency
lock, runner discovery rule or quality threshold changed.

## Validation

- Fresh baseline: **175 QML behavioral cases**, zero failures/skips.
- Retained suite: **148 QML behavioral cases**, zero failures/skips (220 passes
  including hooks); **2 Python tests passed**.
- Full current-worktree Nix gate: **all checks passed**, including all five daemon
  contracts, Rust search, native lint, packaging, generated code and performance.
- Manual warning-fatal QML lint and offscreen Quickshell smoke: **passed**.

Supported co-development commands, from the Projects directory:

```sh
python3 daemon-framework/tools/local-build.py check shelllist --keep-going
python3 daemon-framework/tools/local-build.py develop shelllist --command bash -c \
  'cd /home/laufan/Projects/shelllist && tests/run-qml-tests.sh && python3 tests/test_profile_qml.py'
```

The gate snapshots local Git worktrees; Git-add new files first. It leaves locks,
installed services and live hardware state untouched. Nothing is deployed or
restarted by this pruning pass.
