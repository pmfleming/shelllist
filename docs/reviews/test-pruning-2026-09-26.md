# Test pruning — 2026-09-26

Baseline: clean Shelllist `278ca0b`. This pass uses the existing mixed inventory
convention, not the older `4d5ff24` worktree baseline in the historical review.
Target: nearest integer to 67% of the current baseline:
`round(357 × 0.67) = 239`.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper call sites | 195 | 111 | 84 |
| Executed QML behavioral cases, including data rows | 151 | 117 | 34 |
| Rust tests | 4 | 4 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Combined inventory units** | **357** | **239** | **118** |

**33.05% removed; 66.95% retained.** These mixed units are not independent test
scenarios or a coverage percentage. JavaScript calls count once per source site,
including loops/helpers, rather than once per invocation. Qt lifecycle hooks are
excluded: full Qt totals are **225 → 189**, including **74 → 72** hooks.

The inventory script previously counted only inline `pkgs.runCommand` contract
declarations, missing four existing contracts now using `apiContract`. It now
recognizes both forms. The corrected counter is used for **both** snapshots;
none of the five contract checks was removed or weakened. Infrastructure gates
(packaging, native lint, generated assets/TypeScript, module evaluation,
performance and sibling compatibility) remain additional to this inventory.

## Decisions and remaining coverage

| Removed or narrowed | Retained owner / rationale |
| --- | --- |
| Repeated analyzer-independent presentation catalogues, exact summary/time wording, moon artwork integration and helper-only Wi-Fi/noise-control/closed-window examples | Native view tests, SVG decoding, daemon schemas and stateful consumer scenarios remain. Exact artwork, abbreviations and optional presentation policies are not frozen by separate helpers. |
| Bluetooth header composition, repeated power-cycle subtitles, four disconnected-device layout rows and battery dimming geometry | Actual disconnect/reconnect route guards, per-device audio isolation, failed profile apply/save, adapter and rename acknowledgements, pairing request identity/input recovery, scoped reset and aggregate earbud battery behavior remain. |
| Display information/card composition, repeated search/selection setup and fixed keyboard step sizes | Draft-only settings, empty/disconnected draft recovery, stale provider identities, docking acknowledgement/retry/exclusion, narrow-view focus visibility, topology replacement, preview tokens, pending close and reconnect recovery remain. JS retains exact refresh selection, rotation, invalid/finite geometry, snap distance/ties/thresholds and laptop/last-output protection. |
| Duplicate clipboard prefetch observations and query-reset setup | Native search fencing/paging, explicit retry without loops, revision-checked warm reopen, stale-cursor refresh, hidden-session guard, draft/lease/conflict recovery, background annotation and revision-checked single-dispatch bulk deletion remain. |
| Generic JsonlRouting Qt helper test and transport bookkeeping observations | Node boundary tests still execute the actual routing/consumer functions and protect failed-generation no-replay, protocol/gap handling, subscription cancellation on close/detach, generation fencing, ownership and bounded startup queues. Native Qt session attachment/churn tests remain. |
| Battery control success-return/state/forwarding observations and repeated policy UI catalogues | Edited-device identity and replacement races, editing exclusion/latest retry, global temporary-operation guards and resumption, denied/invalid/pending/disconnected commands, Keep awake release-only behavior, invalid policies, stale telemetry and uncertain outcomes remain. Native Qt tests own wire names/payloads, acknowledgements, notification/profile controls and accessibility. |
| Battery chart forecast labels/range scaffolding and duplicate coordinate/segment assertions | Real isolated 0/100% pixels and discontinuity rendering remain, together with invalid/missing samples, charging estimates, backwards clocks, signed-power gaps, finite zero transitions and duplicate/late live-cache handling. |
| Extra notification classification/compact-time/stack-peek fixtures and duplicate inactive-draft observation | QVariant/Repeater action regression, real keyboard activation, DND acknowledgement, active/history filtering, catch-up, reply acknowledgement/failure, delegate/focus survival, backend failure cleanup, origin navigation and adversarial identity remain. |
| Card/tab geometry matrices, duplicate append scenario, ToggleRow/absent-search variants and straightforward registry/filter propagation | Shared wrapping/hidden-child layout, primary/toggle/workspace activation, disabled/busy guards, slider motion, provider shortcuts, queued surface requests and keyed-model cancellation remain. Selection replacement on hidden/reopened lists was deliberately retained as a regression, rather than removed with ordinary wrapper cases. |
| Application history interim counts and simple lifecycle transition observations | Unsafe revision rejection, target/request/operation isolation, paginated sliding windows, committed-cursor retry, overlap deduplication, nonadvancing-cursor termination, native weighted summaries and unavailable-versus-zero rendering remain. |

Four behavioral Node scripts and their flake invocations were deleted entirely:
`check-application-presentation.js`, `check-bar-surface-recovery.js`,
`check-wifi-icons.js`, and `check-bluetooth-noise-control.js`. The helper-only
`tst_jsonl_routing.qml` suite and its Lens entrypoint were also removed. Remaining
fixtures/imports used only by removed cases were cleaned up.

No test was skipped or renamed out of discovery. Assertions were not moved into
uncounted helpers to reach the target. Whole low-value scenarios and redundant
observations were removed; essential setup actions remain where subsequent
request/output checks still depend on them. The concentrated battery-controller
script retains its original behavioral scenarios rather than repackaging the
removed checks under a new counter.

Tradeoff: fewer direct helper/default/wording checks, less visual-composition and
wrapper-variant coverage, and fewer intermediate-state observations. This is
not a claim of unchanged line/branch coverage or protection against every
previously tested presentation variation.

## Validation

- **117 Qt behavioral cases pass**, no failures/skips; **189 passes** including
  hooks. No QML engine warnings were emitted. Expected negative-test application
  error logs remain allowed.
- All **19 retained behavioral JavaScript scripts** pass through their flake
  checks. Strict native QML lint, TypeScript freshness and packaged imports pass.
- Rust search: **4 passed**, `cargo test --locked --offline`.
- Python profiler: **2 passed**, `python3 tests/test_profile_qml.py`.
- Full **39-check Nix build attempted** with `--keep-going --no-write-lock-file`:
  **38 succeeded**, including cached checks. `nmDaemonContract` still fails on a
  formatting-only difference in `wifi/NmApi.js`'s stream arrays. A temporary clean
  worktree at `278ca0b` reproduced the **identical failing derivation**. The check,
  production file and generator were deliberately left unchanged; the full gate
  is not reported as passing.
- Production implementation, protocol fixtures, generated JS, lockfiles and
  quality thresholds are unchanged. No services or live hardware were touched.

## Reproduce

Use the corrected inventory script for both matching source/log pairs:

```sh
# Run tests at 278ca0b to obtain before-qml.log, then use the current counter:
python3 tests/count-test-inventory.py --revision 278ca0b --qml-log before-qml.log

# Current tree, in the Qt/Nix development environment:
tests/run-qml-tests.sh > after-qml.log
python3 tests/count-test-inventory.py --qml-log after-qml.log
```

Detailed local logs are in the adjacent Lens checkout's ignored
`target/test-pruning-20260926/` directory, including the baseline contract
failure, both inventories, Node/Qt checks, Python/Rust runs and Lens's unchanged
native/package validation gates. Lens's independent reduction is **152 → 102**
Node tests, documented in `qmlqualitylens/docs/test-pruning-2026-09-26.md`.
