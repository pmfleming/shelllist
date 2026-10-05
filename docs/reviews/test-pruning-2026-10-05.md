# Test pruning — 2026-10-05

## Scope and count

Reduce the current test inventory by approximately one third, retaining behavior,
contracts, important regressions and failure handling instead of repeated visual,
wrapper and implementation-shape checks. Production behavior is unchanged.

The baseline is the incoming working tree at `8ca74ce`, including uncommitted Lens
maintenance, not a clean HEAD checkout. It is archived in ignored
`target/test-pruning-current/baseline.tar`, alongside `incoming.patch` and the
successful baseline QML log. Concurrent commit `8f77283` changed the development
tooling references in README/flake; that work was left alone.

| Inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper sites | 118 | 79 | 39 |
| Executed QML behavioral cases, including data rows | 226 | 147 | 79 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **359** | **241** | **118** |

**67.13% retained / 32.87% removed**, the nearest integer to 67% of the baseline.
QML runner totals are **302 → 213**; **76 → 66** lifecycle hooks are excluded.
Test implementation source (`tests/**/*.qml`, `.js`, `.py`) is
**10,336 → 8,603 physical lines**, a reduction of **1,733**.

This is the repository's mixed inventory, not a count of independent scenarios,
assertion executions, or coverage percentage. JavaScript loops count once per
assertion site; QML data rows count separately. Consolidating repeated numeric
validation assertions retains input guards while reducing source sites. It does
not mean every removed unit was a deleted behavior.

Before measuring either snapshot, the inventory counter was corrected to include
`portal-launcher/`, recognize `#[tokio::test]`, and exclude build artifacts. Both
snapshots use that same correction. Runner discovery, skips, failure handling and
contract declarations are unchanged. Lens configuration only loses the five
deleted suite entrypoints; thresholds, roots and exclusions are unchanged.

## Decisions and retained coverage

- **Shared editing is the primary boundary.** Text and multiline save/discard
  binding checks now accompany actual editing workflows; pointer/blur checks
  share the external-update workflow. Numeric Home/End and live rollback remain.
  Forward/reverse positional traversal still covers hidden, disabled and removed
  fields. Command menus, modal ownership, native arrows, switch arrival and
  source updates during drafts remain. Remove repeated control-family matrices,
  bare-slider mapping and consumer copies of the same field/navigation contract.
- **Restoration retains asynchronous failure cases.** Keep deferred loaders,
  recreated views, new-navigation/closure fences, missing results/tabs/editors,
  keyed viewport, password exclusions and value-free memory. Remove repeated
  application/Bluetooth restoration fixtures and identity-toggle bookkeeping.
  The offscreen later-page list reactivation regression remains.
- **Displays retain unsafe-layout and transaction boundaries.** JS checks cover
  numeric limits, duplicate/all-off layouts, invalid mirrors/cycles, all four
  directions and fractional rotated placement. Duplicate identity validation uses
  enabled entries so the all-off guard cannot accidentally satisfy it. Qt retains
  opaque daemon mode IDs, local drafts, pending Preview telemetry, stale tokens,
  replaced connectors, expiry, late/hidden Preview reversion, docking
  acknowledgement/retry and focus-policy validation. Draft/trial docking guards
  accompany the docking workflow. Keep representative keyboard/drag routes and
  Escape/outside/unplug cancellation, not the full direction/size/modifier matrix.
- **Notification catalog and reply regressions remain.** Keep the coalesced
  persisted/transient deletion case, late query replies, cursor/revision fencing,
  atomic paging, viewport retention and the 205-record reply-focus burst. Read and
  reply failures/retry now accompany the reply workflow; stale snapshots accompany
  the event workflow. Remove model-rebuild identity assertions, transport ownership
  duplication, union-list shape and repeated field traversal. Presentation keeps
  adversarial group keys, action classification and the native Repeater payload
  regression; Qt owns message/draft identity checks.
- **Bluetooth and Clipboard retain uncertain outcomes.** Keep pairing identity,
  secrets/closure fences, unavailable projections, capability invalidation,
  failed rename drafts, scoped policy reset, profile acknowledgement/save failure,
  edit leases, conflicts, stale cursors, retries and no-replay recovery. Pairing
  rejection and unavailable profile cases share their corresponding workflows.
  Disconnected cached audio endpoints must remain non-actionable. Late clipboard
  commit failure now participates in draft reload/conflict/discard; hidden recovery
  accompanies transport loss rather than requiring another fixture.
- **Narrow wrappers do not each need a suite.** Delete `tst_battery_tabs.qml`,
  `tst_battery_history.qml`, `tst_wifi_results.qml`,
  `tst_time_weather_selection.qml` and `tst_hyprland_dispatch.qml`. Shared controls,
  keyed models, battery history JS, battery suspend safety, Wi-Fi prompt/portal
  workflows and scoped compositor-command tests remain. Remove repeated native
  shortcut activation, provider projection, default dispatch and tray setup.
- **Avoid freezing implementation shape.** Remove OSD factory key/default-object
  assertions, copied media capability tables and bar secondary-button style checks.
  OSD coverage becomes rejected/lost brightness request cleanup and successful
  recovery, without animation/renderer timing fixtures. Shared controls still
  exercise immediate native value changes; system choosers retain capability and
  explicit media-target guards. Compositor motion keeps wrong-projection filtering,
  stale reads, read/transport failure differences and recovery; shared session
  lifetime is tested in `tst_daemon_sessions.qml`, not again in each consumer.

Consolidation removes redundant fixture setup and repeated assertions; it is not
just renaming several unrelated tests into one function. Distinct safety workflows
remain independently diagnosable. No assertion helpers or test discovery rules
were changed to hide retained tests.

## Changed QML suite counts

| Suite | Before | After |
| --- | ---: | ---: |
| ActionControl | 3 | 2 |
| BarOsdResponsiveness | 7 | 2 |
| BatteryHistory | 1 | 0 |
| BatteryTabs | 1 | 0 |
| BluetoothRecovery | 19 | 10 |
| ChooserGeometry | 5 | 2 |
| ChooserKeyboard | 7 | 5 |
| ChooserMemory | 16 | 11 |
| ClipboardRecovery | 12 | 10 |
| Displays | 39 | 22 |
| DomainWorkflows | 3 | 2 |
| FieldInteraction | 27 | 15 |
| HyprlandDispatch | 1 | 0 |
| IpSettingsState | 2 | 1 |
| MaterialBar | 5 | 3 |
| NativeCompositorMotion | 2 | 1 |
| NotificationActions | 2 | 1 |
| Notifications | 17 | 11 |
| ProviderRegistry | 2 | 1 |
| ProviderShortcuts | 2 | 1 |
| ResultListReactivation | 3 | 2 |
| ResultStore | 2 | 1 |
| SettingsControls | 3 | 2 |
| SystemChoosers | 6 | 5 |
| TimeWeatherSelection | 1 | 0 |
| WifiResults | 1 | 0 |

Other suites are unchanged from the incoming tree: BatterySuspend, DaemonSessions,
ImageAssets, KeyedListModel, MaterialFields, MaterialPalette, NativeWorkArea,
SurfaceActions, SurfaceRegistry, WifiCasting, WifiPortal and WifiPrompt. All eight
Rust tests, two Python tests and five daemon contract declarations are retained.

## Deliberately reduced evidence

There is less direct coverage of OSD renderer/animation behavior, exact geometry,
per-panel narrow layouts, battery tab wiring, empty Wi-Fi presentation, weather
selection wiring, Bluetooth invocation/headset presentation and application menu
restoration. Not every control family is tested with every save/discard/binding
combination. Native display input covers representative directions, while JS
covers directional arithmetic. Shared controls do **not** prove all removed
consumer wiring, and fewer tests are not evidence of equivalent branch coverage.

No matched performance benchmark or complete runtime coverage claim is made.
Hardware, live compositor, IME and screen-reader acceptance remain separate.
The interaction contract itself is unchanged; its validation description now
accurately distinguishes representative Qt routes from JS arithmetic checks.

## Validation and reproduction

Passed:

- QML: **213 passed**, comprising **147 behavioral cases + 66 hooks**; zero
  failures, skips or blacklisted cases.
- All **16 behavioral JavaScript scripts**, plus source-tree relative-import
  resolution (not a new installed-package/Nix build).
- Strict QML lint, native runtime smokes, TypeScript typechecking (`tsc --project
  tsconfig.json`), **8 Rust tests**, **2 Python tests**, and `git diff --check`.

`node tools/build-typescript.mjs --check` fails because incoming
`bar/BarOsdPresentation.js` does not match `typescript/bar/BarOsdPresentation.ts`.
The same failure was reproduced from the archived baseline. Neither source was
changed in this pass. The coordinated sibling Nix gate and daemon contract
executables were **not rerun**; retained declarations are not a fresh release pass.
No services were activated or restarted.

Commit isolation excludes the preexisting Lens production/test hunks and
`flake.nix` change. An archived staged tree independently passes all **213 Qt
checks** and retains the **241-unit inventory**; generated-TypeScript verification
also passes there. The generation drift above belongs to the excluded incoming
work. Evidence: `staged-qt.log` and `staged-typescript.log` in the same evidence
directory.

```sh
tests/run-qml-tests.sh > /tmp/pruned-qml.log 2>&1
python3 tests/count-test-inventory.py --qml-log /tmp/pruned-qml.log
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
python3 tests/test_profile_qml.py
tsc --project tsconfig.json
# With the Rust development tools on PATH:
for manifest in rust/shelllist-search/Cargo.toml \
                rust/shelllist-timezone-assets/Cargo.toml \
                portal-launcher/Cargo.toml; do
  cargo test --manifest-path "$manifest" --locked --offline
done
```

Local evidence: `target/test-pruning-current/{before,after}.json`,
`{before,after}-qt.log`, `checks.log`, `lint.log`, `smoke.log`, `rust.log`,
`python.log`, `tsc.log`, and `before-typescript.log`. `checks.log` records the
successful JavaScript checks followed by the known generated-TypeScript failure.
To recount the baseline, extract `baseline.tar` into an isolated directory, copy
only the corrected inventory script into its `tests/`, and run that script with
the absolute path to `before-qt.log`. `before-recount.json` matches `before.json`.

This target is a one-time pruning checkpoint, not a permanent cap. Add focused
regressions when meaningful new failures are found.
