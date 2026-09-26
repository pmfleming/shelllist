# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables or freeze visual choices unnecessarily.

## QML validation environment and warning regressions

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG image plugins and a timezone database;
both QML runner scripts use the same offscreen/software, UTC setup. Refresh an
already-open development shell after changing `flake.nix`.

- `tst_image_assets.qml` checks that representative weather and timezone SVGs
  actually reach `Image.Ready`, rather than passing while Qt logs decode failures.
- `tst_provider_shortcuts.qml` checks keyboard activation and reactive help updates
  when a shortcut's sequence/help or the explicit `helpShortcuts` list changes.
  Consumers list their shortcuts in `ProviderChooserSurface.helpShortcuts`; do not
  bind help generation to non-notifiable `Item.resources`.
- Notification view tests destroy their content before its controller/state, and
  reject unexpected JavaScript/binding warnings during the lifecycle.

These are additional regression checks, not a revision of the historical pruning
baseline below. Expected negative-test application error logs are distinct from
QML engine warnings and remain allowed.

## Current pruning inventory

Baseline: the incoming worktree at `4d5ff24`, **including its existing uncommitted
changes**. This supersedes the earlier 646 → 433 inventory; that historical
baseline is not the baseline for this pass. Sibling repositories are not pruned.

Shelllist has ad-hoc JavaScript checks, QtTest, Rust and Python, not one
runner-reported total. The existing counting convention and
`count-test-inventory.py` are unchanged:

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper call sites | 287 | 178 | 109 |
| Executed QML behavioral cases, including data rows | 184 | 134 | 50 |
| Rust test functions | 4 | 4 | 0 |
| Python test methods | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Combined inventory units** | **482** | **323** | **159** |

**32.99% removed; 67.01% retained**: 323 is the nearest integer to
`482 × 0.67 = 322.94`. These mixed units are **not independent scenarios or a
coverage percentage**. JavaScript counts line-leading assertion/helper calls
once per source site, including loops/helpers, not once per invocation.
Qt's full runner totals are **256 → 202**, including **72 → 68** lifecycle hooks
excluded from the inventory. Two redundant QML suites were deleted entirely.

Both whole scenarios and redundant observations within retained scenarios were
removed. Setup actions remain when later request/output assertions already
prove their result. Tests were not skipped or renamed out of discovery, and
assertions were not moved into uncounted helpers to reach the target.

Infrastructure gates remain additional and unpruned: packaging/imports, module
evaluation, generated assets/TypeScript, native lint, performance,
application-resource fixture compatibility and native hypridle readiness.
The five counted contract suites are the `*DaemonContract` flake checks.

### Reproduce

Local evidence is in the ignored `target/test-pruning/` directory:
`pre-existing.patch`, `before-counts.json`, `before-qml.log`, `after-counts.json`
and validation logs. Reconstructing the baseline requires both `4d5ff24` and
that incoming patch, not just a pristine Git revision.

```sh
# Run on the reconstructed incoming worktree before pruning:
tests/run-qml-tests.sh > target/test-pruning/before-qml.log
python3 tests/count-test-inventory.py \
  --qml-log target/test-pruning/before-qml.log

# Run on the retained worktree:
tests/run-qml-tests.sh > target/test-pruning/after-qml.log
python3 tests/count-test-inventory.py \
  --qml-log target/test-pruning/after-qml.log
```

The source and QML log must match. The inventory script rejects incomplete,
failing, skipped or duplicate-case Qt logs; it does not infer a revision from
logs. Do not count today's sources against the baseline log.

## Removal decisions and remaining owners

| Removed or reduced | Remaining owner / rationale |
| --- | --- |
| Battery success-return/internal-state assertions and duplicated backend forwarding checks | JS retains edited-device identity, removal/replacement races, autosave exclusion, global operation guards, AC/cancellation, denied capabilities, invalid actions, policy validation, failed saves and transport uncertainty. Requests are observed instead of checking every intermediate boolean. Qt retains acknowledgement, keep-awake acquisition/release, keyboard/accessibility, unknown outcomes and actual daemon wire names. |
| Fixed battery tab/card placement, legend labels, chart bounds, hibernate wording and repeated level controls | Qt retains profile keyboard/busy behavior, independent notification flags, selected-device settings and charge-target changes. Shared layout tests own hidden children, wrapping, headings and footer bounds. Battery chart tests retain actual isolated 0/100% pixels, charge gaps, forecast/hover and range/live updates; JS retains invalid/missing samples, charging estimates, signed power areas, zero transitions and duplicate/late cache handling. |
| Daemon subscription bookkeeping, exact sequence IDs and repeated lifecycle observations | Retain failed-generation no-replay, protocol/version/gap handling, late/closed/detached subscription cancellation, pending reopen coalescing, base-subscription recovery, resident-client survival, generation fencing, event ownership and bounded startup queues. Real Qt session tests still cover ready attachment and request churn. |
| Application history interim counters and cancellation bookkeeping | Retain target/range isolation, stale replies, paginated catch-up, sliding-window pruning, committed cursor retry, overlap deduplication, nonadvancing cursors and frozen request windows. Resource checks retain unavailable/null versus measured zero and rejection of battery discharge as per-app power; Qt retains native summary consumption and canvas gaps. |
| Bluetooth duplicate prompt setup, global tab/default matrices, busy subtitle and pending-preference bookkeeping, artwork/scan-text/helper lifecycle checks | Recovery tests retain prompt/input/request identity, failed replies, unavailable services, live reconnect, opaque audio keys, apply-before-remember identity, save failures, rename/adapter recovery and scoped reset. Global request scope is checked in the retained acknowledged list-settings test. JS retains mine/all filtering, display-passkey progress, pair rescan policy, trust and unknown-action guards. |
| Repeated per-consumer detail layouts (`tst_detail_pages.qml`), display size matrices, action hierarchy and docking placement | `tst_detail_layout.qml` owns shared layout contracts; launcher transitions and narrow display focus visibility remain. Displays retain draft-only editing, stale identity/topology, preview tokens, confirm/revert, pending-close and reconnection recovery, docking acknowledgement/retry and docking exclusion during layout edits. JS retains exact modes, mixed-DPI/rotation geometry, invalid inputs, finite rectangles and last-output/internal fallback protection. |
| Clipboard full-height tab composition and notification expansion/preview geometry duplicates | Clipboard retains tab draft survival, visible/hidden transport behavior, query fencing, paging/coalescing/retry, leases/conflicts, annotation lifecycle and revision-checked bulk deletion. Notifications retain real reply delegate/focus survival, acknowledgement/failure, inactive replies, catch-up, DND and navigation origin. |
| Repeated shared activation wrappers, busy ToggleRow test, tooltip absence, exact subtitle truncation and extra Alt+Enter variants | Representative button/toggle/switch/workspace controls retain pointer, keyboard and assistive activation, busy/disabled guards and focus. Bar secondary activation, media click routing/unseekable guards, search disabled/absent states and slider keyboard accessibility remain. |
| Non-empty JS ranking helper checks and standalone Model utility stress fixture (`tst_model_quality.qml`) | Actual non-empty search uses Rust, whose four tests remain. JS retains baseline score ordering, missing/duplicate action rejection and cross-provider batch rejection. Qt retains registry dispatch rejection, asynchronous ranking boundaries, keyed delegate identity and large/progressive model updates. |
| Bar presentation catalogues, update-job appearance, low-confidence badge styling, simple weather selection/construction and repeated chart/work-area variants | Retain monitor isolation, bounded/live media progress, muted OSD semantics, essential narrow-screen actions, all brightness failure routes, resume generations, native work-area gaps, negative-origin/tiny-screen bounds, same-index weather replacement, native lunar/solar updates, local-time offsets and hourly clock advancement. |

Tradeoff: exact visual composition, all wrapper/key/size combinations, helper
bookkeeping, artwork choice and some status wording no longer have dedicated
checks. Shared contracts and higher-value consumer regressions remain; this is
not a claim of unchanged line/branch coverage.

No production implementation, protocol fixture, lockfile, discovery rule or
quality threshold was changed by this pass. Flake test invocations dropped
unused fixture arguments; the lens configuration dropped only the deleted
`DetailPages` test entrypoint. Unrelated worktree edits remain untouched.

## Validation

- Baseline Qt: **184 behavioral cases**, zero failures/skips.
- Retained Qt: **134 behavioral cases**, zero failures/skips (**202 passes**
  including hooks).
- All **23 behavioral JavaScript scripts passed**, using the arguments from
  their flake checks.
- Rust search: **4 passed** (`cargo test --locked --offline`).
- Python profiler: **2 passed** (`python3 tests/test_profile_qml.py`).
- Native QML lint, TypeScript generation check and `git diff --check`: passed.
- Full co-development Nix gate: **blocked before checks ran** by untracked files
  in the sibling `bar-daemon` worktree. Those files were not staged or changed.
  Consequently this pass does not claim fresh full packaging/daemon-contract
  validation. Live hardware was not exercised.

Retry the full gate from the Projects directory once sibling worktrees are
ready:

```sh
python3 daemon-framework/tools/local-build.py check shelllist --keep-going
```

No services or live hardware were deployed, restarted or reconfigured.
