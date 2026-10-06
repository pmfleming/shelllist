# Test pruning — 2026-10-06

## Scope and accounting

Requested: retain approximately 67% of the current test inventory, preferring
behavior, contracts, regressions and failures over repetition and implementation
snapshots. Baseline is `8f47572` **plus the incoming uncommitted media changes**,
not that revision alone. Frozen sources, incoming patch and successful baseline
Qt output are under ignored `target/test-pruning-2026-10-06/`.

| Established inventory unit | Before | After | Removed |
| --- | ---: | ---: | ---: |
| JavaScript assertion/helper sites | 83 | 47 | 36 |
| Executed QML behavioral cases/data rows | 216 | 148 | 68 |
| Rust tests | 8 | 8 | 0 |
| Python tests | 2 | 2 | 0 |
| Daemon contract suites | 5 | 5 | 0 |
| **Total** | **314** | **210** | **104** |

`round(314 × 0.67) = 210`: **33.12% reduction; 66.88% retained**.
Qt's complete runner totals are **286 → 212**, including **70 → 64 lifecycle
hooks**, which the inventory excludes. Three suites were deleted.

The contract counter previously missed two line-wrapped declarations. Its regex
now permits whitespace/newlines around the builder assignment. Both source
snapshots were counted with this corrected script: five declarations, not three.
The frozen baseline recount matches `before.json`. Other counting rules and
rejection of incomplete/failing/skipped/duplicate-case logs are unchanged.

**These are mixed inventory units, not independent scenarios or a coverage
percentage.** The JavaScript reduction is mostly consolidation of repeated
assertion sites, not removal of 36 behaviors. Validation tables still execute
all their retained inputs. Qt really executes 68 fewer behavioral cases; this is
not achieved by skipping cases or hiding them in renamed helpers. More than
1,300 test-source lines are removed, including obsolete fixtures.

No production behavior changes. Incoming media production changes and icon/artwork
regressions remain; `tst_bar_material.qml` was pruned only outside its incoming
artwork test. Lens loses the two explicit entrypoints for deleted suites; no
thresholds, warning suppressions or test-runner exclusions were added.

## Decisions

### Remove broad presentation/implementation fixtures

- Delete `tst_settings_controls.qml`, `tst_material_palette.qml` and
  `tst_chooser_geometry.qml`. Their wrapper sizes, token types, motion snapshots
  and broad geometry fixture overlap native field transactions, painted contrast,
  native-window smoke, work-area recovery, navigation and keyed list tests.
- Keep one shared activation representative (ToggleSwitch), including keyboard,
  pointer, assistive press/toggle and busy/disabled guards; remove repeated button
  and workspace wrapper rows.
- Keep actual filled-field pixels across light/dark schemes and seven accent
  seeds. Remove token/geometry/animation snapshots; JavaScript still checks
  contrast across 150 seed/mode combinations.
- Keep representative narrow-header circular footprints, primary hierarchy,
  title/command separation and accessibility; recovery-command independence,
  modal traversal, duplicate-letter/AltGr/overflow guards and captured selection
  through close-time model reordering. Remove repeated width, sizing and action
  wrapper cases. Keep bar caret/focus and pointer overflow reachability.
- Keep notification Repeater/array-like payload behavior; remove redundant
  notification-specific command-menu and standalone animation-completion tests.

### Reduce duplicated workflows and Cartesian products

- Notifications: retain real search and obsolete-success rejection; representative
  ordinary-error-before-replacement and stale-error-after-publication cases;
  duplicate completion; queued revision changes; read failure and epoch change
  between refresh pages; atomic publication, stale cursor/nonprogressing pages,
  identity/generation fencing and reply focus through 205 records. Reduce the
  schema matrix to missing page, wrong query, invalid cursor, duplicate record
  and invalid ID. Drop the full outcome/timing product and overlapping transient
  replacement/history scenario.
- Chooser/field suites: drop duplicate secondary pointer/Alt routing, a resource
  composition/status workflow, long-modal scrolling, redundant happy-path loader
  restoration, missing-result invocation and implementation-specific form identity
  checks. Existing loader restoration now also verifies caret/selection. Keep
  native slider Home/discard plus complete deferred/live-preview workflows;
  remove the extra End row, unbound-field and multiline viewport scenarios.
- Displays: retain a representative keyboard direction and pointer direction,
  Escape cancellation, reference save/discard, local-only mode drafts, unsafe
  topology, trial/acknowledgement, docking and focus-policy failures. JavaScript
  retains all four directional calculations. Remove repeated placement/outside
  cancellation and presentation/provider-wiring scenarios. Stale provider identity
  rejection moves into physical connector replacement, with a cloned snapshot so
  the obsolete result cannot be mutated through shared fixture references.
- Clipboard: keep the actual keyboard lease commit without per-keystroke writes;
  remove its extra discard row. Closure/pending-read and failed-edit recovery
  remain. Bluetooth's existing audio-profile workflow now ends with remember-policy
  failure instead of success, retaining its distinct failure without another full
  fixture. Battery's degraded Keep-awake workflow now also checks acknowledged
  switch state, ability to release it and suspend/hibernate versus lock guards;
  remove the separate visual/old-daemon-field case.
- Wi-Fi: drop duplicate lifecycle merge precedence and bar fallback wiring, one
  claim result variant and the overlapping automatic-claim disappearance path.
  Keep user-command keys, claimed URL/workspace, expiry/network change,
  generation/late-response fences, process failure and uncertain no-replay paths.
- Drop the media transport-mapping matrix (explicit targets/capabilities remain in
  system chooser workflows) and the source-shaped compositor blur-command test.

### Simplify JavaScript without discarding validation boundaries

- Tables share assertions for rejected display layouts, battery samples,
  application lifecycle boundaries, resource availability, daemon health
  recommendations, provider rejection cases and color contrast pairs. Their
  unsafe/invalid inputs remain executable, with labels identifying failures.
- Compare cohesive outputs together for history polling/deduplication, battery
  draft/acknowledgement state, bulk clipboard requests and daemon
  delivery/recovery/cancellation. Guards are still checked, not replaced by a
  single happy-path result. IP diagnostics compare the address/octet pair, and
  the overlong-prefix input joins the existing prefix table.
- Remove the legacy action-width normalization assertion and a suspend
  transport-error wording-only scenario. Keep actual denied/pending/unavailable/
  disconnected dispatch guards, policy acknowledgement loss and native uncertain
  outcome safety. Remove pure notification reply classification duplicated by
  actual Qt consumers; retain adversarial group identity.
- All 16 behavioral JavaScript scripts remain. No assertions were moved to
  uncounted helper files or hidden behind aliases. Sites intentionally count
  differently from runtime input combinations, as they did before this pass.

## Changed Qt inventory

Unlisted suites are unchanged from the incoming baseline.

| Suite | Before | After |
| --- | ---: | ---: |
| ActionControl | 3 | 1 |
| BarOsdResponsiveness | 3 | 2 |
| BatterySuspend | 5 | 4 |
| BluetoothRecovery | 10 | 9 |
| ChooserGeometry | 2 | 0 |
| ChooserKeyboard | 7 | 4 |
| ChooserMemory | 11 | 9 |
| ClipboardRecovery | 10 | 9 |
| Displays | 22 | 17 |
| DomainWorkflows | 2 | 1 |
| FieldInteraction | 17 | 13 |
| IpFields | 7 | 4 |
| MaterialBar | 7 | 5 |
| MaterialFeedback | 9 | 2 |
| MaterialFields | 4 | 2 |
| MaterialPalette | 1 | 0 |
| NotificationActions | 3 | 1 |
| Notifications | 34 | 20 |
| SettingsControls | 2 | 0 |
| SurfaceActions | 13 | 5 |
| WifiPortal | 14 | 11 |
| WifiPrompt | 3 | 2 |

## Deliberate coverage reductions

This does **not** establish identical branch coverage. There is less direct
coverage of per-wrapper routing/sizes, circle scale matrices, palette token types,
vertical/mirrored sliders, RTL segment navigation, immediate decorative feedback,
animation completion, compact/unit/read-only form geometry, native slider End,
unbound editors and multiline viewport scrolling. Broad negative-origin/fallback,
fractional anchoring and live-resize geometry also lose their dedicated fixture.

Some happy-path restoration, missing-result invocation, per-panel composition,
provider wiring, outside-drop cancellation and bar portal fallback receive less
direct evidence. Notification schema variants (including separate page/window
bounds and malformed token/timestamp shapes), some old-query timing combinations
and hidden-panel continuation abandonment are no longer individually enumerated.
Their production guards remain unchanged; representative invalid-page, revision,
epoch, generation, cursor and no-replay scenarios remain tested.

The [interaction contract](../chooser-keyboard-workflow.md) is unchanged. Passing
shared tests does not prove every consumer is wired correctly. Add focused tests
for meaningful newly discovered failures; 210 is not a permanent cap. Offscreen
runs do not establish live compositor/hardware/IME/screen-reader acceptance.

## Validation and reproduction

Passed on the pruned tree:

- **212 Qt passes: 148 behavioral cases + 64 hooks; zero failures/skips.**
- All 16 JavaScript behavioral scripts, including unchanged Bluetooth lifecycle
  and resource availability, plus source-tree relative import checks.
- Strict `qmllint`, native runtime smoke, generated TypeScript parity and `tsc`.
- Eight Rust tests (search and portal launcher); timezone-assets target has no
  unit tests. Both Python profiler tests pass.
- `git diff --check`; source comparison against the incoming archive finds no
  production changes attributable to this pass.

All five daemon contracts are retained unchanged. Their executables and the full
sibling-aware Nix gate were **not rerun**. Earlier full-gate timeouts remain
unverified, not a pass. No deployment or live backend mutation was performed.

```sh
tests/run-qml-tests.sh > target/test-pruning-2026-10-06/after-qt.log 2>&1
python3 tests/count-test-inventory.py \
  --qml-log target/test-pruning-2026-10-06/after-qt.log
tests/run-qmllint.sh
tests/run-runtime-smoke.sh
bash target/test-pruning-2026-10-06/run-checks.sh
# The local evidence script records the 16 flake.nix nodeCheck invocations,
# imports, generated-source parity, tsc and Python tests.
cargo test --locked --offline --manifest-path rust/shelllist-search/Cargo.toml
CARGO_TARGET_DIR="$PWD/target/timezone-test" cargo test --locked --offline \
  --manifest-path rust/shelllist-timezone-assets/Cargo.toml
cargo test --locked --offline --manifest-path portal-launcher/Cargo.toml
git diff --check
```

Evidence: `baseline.tar`, `incoming.patch`, `baseline-source/`, `before-qt.log`,
`before.json`, `before-recount.json`, `after-qt.log`, `after.json`,
`comparison.json`, `checks.log`, `rust.log`, `lint.log`, `smoke.log` and the
focused `notifications.log`, all under `target/test-pruning-2026-10-06/`.
`baseline-source/` differs from the archived baseline only in the corrected
inventory script used for the matched recount.
