# Test scope

Keep tests at the narrowest **behavioral boundary** that catches a meaningful
failure. Prefer representative scenarios over repeated fixtures. Do not mirror
implementation tables or freeze visual choices unnecessarily.

## QML validation environment and warning regressions

Run `tests/run-qml-tests.sh` from `nix develop`. The development shell and Nix
`qmlTests` check provide matching Qt SVG image plugins and a timezone database;
both QML runner scripts use the same offscreen/software, UTC setup. Refresh an
already-open development shell after changing `flake.nix`.

- `tst_material_palette.qml` checks live seed/mode changes, reference colors,
  exact foreground bindings and opaque control fills.
  `check-material-colors.js` checks contrast in 150 seed/mode combinations.
  Nix checks also rebuild/compare the generated bundle/license and launch the
  development gallery in both modes with its two candidate fonts.
- `tst_image_assets.qml` checks that a representative weather SVG actually
  reaches `Image.Ready`, rather than passing while Qt logs decode failures.
- `tst_provider_shortcuts.qml` checks live shortcut changes/disabled guards and
  verifies that F1/question marks cannot summon a help overlay, steal editor
  focus or insert an extra Escape layer. Domain bindings use Qt `Shortcut`.
- `tst_focus_feedback.qml` checks immediate focus transfer, retained busy focus,
  tonal mouse/keyboard/browse parity, borderless inset bounds, circular workspace
  highlights, selection versus focus, non-selecting hover and tooltip absence.
- `tst_expressive_controls.qml` covers press/reversal while activation and focus
  remain immediate, busy/focus-loss cleanup and stopping in-flight springs when
  motion is disabled. It also compares shared numeric/color interpolation with
  native Qt references and checks reversal/no-motion endpoints. These feature
  regressions were added after pruning.
- `tst_settings_controls.qml` checks immediate slider value/focus feedback,
  native pointer mapping in horizontal/mirrored/vertical layouts, keyboard edits
  and segmented radio semantics, disabled guards and mirrored navigation.
- `tst_material_fields.qml` checks native editing/read-only behavior, masking and
  guarded embedded actions, immediate focus/error roles, hover-independent menu
  navigation, acknowledged selection, Escape cancellation and disabled guards.
- `tst_chooser_keyboard.qml` exercises saved-cursor result typing, contained wrapping
  Tab/Shift+Tab, forward/reverse Ctrl+Tab, Enter-to-edit, guarded Alt+number header
  shortcuts, editor-to-browse traversal, native menu Escape, pending editor
  ownership, actual Applications settings, read-only scrolling, removed editors
  and modal focus containment/restoration, with decorative animations enabled.
  Bluetooth recovery tests also cover its actual adapter-settings keyboard
  journey and clearing/fencing sensitive prompts on whole-surface closure.
  The suite now has 218 behavioral cases (300 passes with hooks); the inventory
  below is the completed pruning checkpoint, not a permanent cap on feature tests.
- `tst_chooser_geometry.qml` covers anchored expansion, work-area bounds and
  fallback, stable frame/list/text/control sizes, minimum and emergency canvases,
  focused-delegate query/guard/detail routing, keyboard overflow revelation and
  the actual Activity rail. Displays retains its safety
  tests with split overflow replacing the rejected narrow single-pane assertion.
  Runtime smoke also exercises the shared visual bounds in a native offscreen
  floating window, including native frame delivery through public `Window.window`;
  live layer placement and input-mask acceptance are separate.
- `tst_system_choosers.qml` covers explicit media targeting, capability/disconnect
  guards, acknowledged volume/mute/pin/mode settings, playback action state, no
  restoration replay, supplied tray icons, identity ambiguity, and native-menu
  focus/lifetime through a recording platform boundary.
- `tst_bar_material.qml` covers ordered continuous groups at normal/compact/emergency
  widths, pictorial/nonvisual values, urgency, overflow access and mode capabilities.
- Activity regressions verify a schedule-only rail in overview and expanded mode,
  removal of its weather/notification shortcuts, retained dates/todo drafts, and
  notification-history activation only through the standalone Notifications surface.
- `tst_domain_workflows.qml` covers the panel adapter, native multiline arrows and
  layered Escape, value-free editor selection restoration, and ordinary Activity
  typing without the former letter shortcuts, and exclusion of revealed sensitive
  inputs. Memory tests cover named list controls plus disabled/removed fallbacks;
  Bluetooth tests cover independent adapter/tab records. Notifications' live-reply test now
  explicitly opens its inspector before verifying stable delegates and drafts.
- `tst_chooser_memory.qml` covers stable per-result/tab scroll and editor memory,
  focus-safe asynchronous restoration, explicit close, immediate row toggles,
  reorder/removal/reconnect, disabled/missing/password targets and invalid tabs.
  Invocation cases also cover ordinary region/editor focus, backward selections,
  clamping without value restoration, keyed viewports, recreated visual trees,
  newer input/menu cancellation, focus-loss context changes and stale callbacks.
  Actual Applications tests exercise collapsed-menu restoration and fresh history;
  Bluetooth recovery covers device/adapter editors, refresh readiness, an empty
  device list, changed adapters and sensitive closure without replaying edits.
- `tst_battery_history.qml` also checks explicit keyboard/pointer inspection:
  hover/focus alone reveal no values, and editor Escape wins over the shared
  surface shortcut before the next Escape dismisses the surface.
- `tst_action_control.qml` also checks one-time default details routing and the
  shared bar color tokens. `tst_clipboard_recovery.qml` verifies actual Clipboard
  routing specialization, unsupported-kind guards and busy replay rejection.
  `check-provider-model.js` covers shared settings-toggle defaults, overrides and
  non-mutating normalization.
- `tst_notification_actions.qml` owns shared quick-action keyboard/pointer,
  disabled activation, focus containment and hidden-reply layout behavior.
- `tst_daemon_sessions.qml` checks default/explicit cancellation IDs and consumer
  routing, including Qt's omitted typed-string argument conversion.
  `tst_result_store.qml` also checks provider-owned identity, non-mutating
  normalization, typed prefix descriptors and shared batch projection through
  a domain override.
- `tst_keyed_list_model.qml` checks arbitrary string identities and cancellation
  of stale queued updates. Notification view tests own native action-array
  rendering and live reply focus through a 205-record burst, destroy content
  before controller/state, and reject JavaScript/binding warnings.
- `check-display-model.js` covers exact modes, finite geometry, invalid fields,
  unsafe layouts and mirror-source constraints. Native Displays tests retain
  draft isolation, topology changes, daemon preview tokens and revert safety.

Expected negative-test application error logs are distinct from QML engine
warnings and remain allowed.

## Latest pruning checkpoint — 2026-09-27

Baseline: clean `2961774`. Nearest-integer 67% target: **298 → 200** units
(**32.89% removed; 67.11% retained**). Sibling repositories are not pruned.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 152 | 81 |
| Executed QML behavioral cases | 135 | 108 |
| Rust tests | 4 | 4 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **298** | **200** |

This is the established mixed inventory, **not independent scenarios or a
coverage percentage**. The counter and discovery rules are unchanged. QML
lifecycle hooks are excluded: **211 → 174 passes** include **76 → 66 hooks**.
No tests were skipped or hidden from discovery, and assertions were not moved
into uncounted helpers. Production implementation and quality thresholds are
unchanged; the Lens entrypoint list only drops the five deleted QML suites.

Strict lint, 108 native behavioral cases, runtime smoke and the full
sibling-aware Nix gate pass, including all five daemon contracts, generated
assets/TypeScript, packaging, Rust tests and performance checks. Both Python
profiler tests also pass in a separate run.
There is less direct helper, visual-layout and optional presentation coverage;
shared contracts do not replace every removed consumer scenario.
See the [current review](../docs/reviews/test-pruning-2026-09-27.md) for removal
rationale, explicit tradeoffs and reproduction commands. Matching baseline/final
logs and inventories are in ignored `target/test-pruning-20260927/`.

## Historical pruning inventory — 2026-09-26

Baseline: clean `278ca0b`. Nearest-integer 67% target: **357 → 239** units
(**33.05% removed**). Sibling repositories are not pruned.

| Inventory unit | Before | After |
| --- | ---: | ---: |
| JavaScript assertion/helper sites | 195 | 111 |
| Executed QML behavioral cases | 151 | 117 |
| Rust tests | 4 | 4 |
| Python tests | 2 | 2 |
| Daemon contract suites | 5 | 5 |
| **Combined inventory units** | **357** | **239** |

This mixes assertion sites and runner cases, not independent scenarios or a
coverage percentage. QML lifecycle hooks are excluded: **189 passes** include
117 behavioral cases and 72 hooks. All 19 remaining behavioral JS scripts,
Qt tests, four Rust tests and two Python tests pass.

The counter now recognizes both `apiContract` and `pkgs.runCommand` declarations;
the same corrected counter produces both inventories. Four existing daemon
contracts were missed by its old syntax matcher; no contract was removed.

Full Nix validation: **38/39 checks succeeded**. `nmDaemonContract` has an
unchanged formatting-only failure reproduced at the baseline commit. It remains
a failing gate, not an exclusion. See the [historical review](../docs/reviews/test-pruning-2026-09-26.md)
for decisions, coverage tradeoffs and reproduction commands.

## Historical pruning inventory

The remainder records the previous pass, not today's coverage or validation.
Its baseline was the incoming worktree at `4d5ff24`, **including its existing
uncommitted changes**. That pass superseded the earlier 646 → 433 inventory.

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

## Historical removal decisions and remaining owners

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

## Historical validation

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
