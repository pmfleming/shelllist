# QML quality and maintenance

Shelllist treats `qmllint`, QML tests, JavaScript policy tests, daemon-contract checks, and the Nix build as authoritative. `qmlqualitylens` is an additional structural review tool; generated reports live under `target/` and are not a release contract.

## Current structure

The UI is divided by ownership rather than by screen size:

- `shell/` owns the resident host, surface registry, IPC, and monitor-local bar creation.
- `bar/` owns bar, active notification, and OSD presentation only.
- `activity/`, `battery/`, `launcher/`, `wifi/`, `bluetooth/`, and `clipboard/` own domain-specific controllers and views.
- `Shelllist.Core` owns provider contracts, normalization, ranking, and keyed result models.
- `Shelllist.Io` owns daemon transport and process boundaries.
- `Shelllist.Ui` owns theme tokens, windows, chooser layout, controls, state layers, elevation, details, prompts, and navigation.

Rust daemons remain responsible for system parsing, identity, validation, policy, and effects. QML should not grow alternate compositor, NetworkManager, BlueZ, PipeWire, process, or clipboard parsers.

## Maintained design decisions

- One `shell/shell.qml` host replaces per-surface Quickshell processes.
- Wi-Fi and Bluetooth load eagerly; Applications and Clipboard load on demand and remain warm.
- `ProviderChooserSurface` composes chooser shortcuts, split layout, density, default navigation/refresh/detail policy, and navigation help once for Wi-Fi, Bluetooth, Clipboard, and Applications.
- `ChooserShortcuts` centralizes Escape, refresh, and details-tab shortcuts.
- `ChooserListPane` derives its own density instead of requiring every domain wrapper to forward presentation state.
- `ResultStore` reconciles one persistent keyed model instead of replacing ListView models.
- Providers resolve dynamic actions at use time rather than copying actions into recurring snapshots.
- `BarContent` renders normalized status descriptors through one delegate.
- Workspace, focused-window, media, tray, and OSD presentation are isolated components.
- Activity, battery, power, and OSD views are split into cohesive panes rather than one large object tree.
- `ChartFrame`, `LiveClock`, `PulsingLabel`, `NotificationReplyRow`, and `BarOverlayWindow` centralize repeated presentation behavior.
- `ChartDrawing` shares gap-preserving Canvas paths between battery and application history; `ChartValueRail` keeps their label geometry and styling consistent. Availability, axes, and telemetry policy stay with their existing owners.
- `NotificationPresentation`, `NotificationStackHeader`, and `RemovalAnimation` keep grouping, routing, stack headers, and transient removal behavior common between active and historical notifications.
- Every OSD family uses one normalized descriptor, one `BarOsdContent` frame, and one dismissal timer; pure transition and timeout policy stays in `BarOsdPresentation.js`.
- `StateLayer` and `Elevation` centralize interaction feedback and depth.
- UI operation-state transitions are kept in small testable JavaScript helpers. Authoritative operation lifecycle policy, validation, leases and effects belong in the owning Rust daemon.
- Terminal backend events are correlated by request/operation IDs before changing UI state.

## Reachability evidence

`qmlqualitylens.config.json` declares the resident shell and QML test files as entrypoints. It also records dynamic component edges hidden behind `Component`, `Loader.sourceComponent`, and `SplitChooserLayout` factories. These edges are analysis metadata, not runtime dependencies. Keep them synchronized when a surface gains or removes dynamically instantiated content; prefer an explicit edge over a broad unused-component suppression.

The current calibration reaches 280 of 282 components from 34 configured/discovered application and test roots. The remaining components are exported module API rather than dead-code findings. Configured edges cover list, details, toolbar, tab, battery, and Time & Weather components instantiated through loaders; cleanup reports no unused components or IDs. Resolution has no unresolved imports; one internal test type (`Launcher.ApplicationSettingsPage`) remains unresolved by Lens, while native Qt lint is clean.

## Focused declarative-state refactoring

When a property is intentionally mutable, initialize it as state rather than first creating a binding that an event handler later destroys. Keep responsive defaults in separate readonly derived properties. Similarly, an animated geometry axis must have one owner: do not combine `anchors.fill` with an explicit animated `x` or `y` binding.

The focused passes applied these rules to bar surface recovery, media progress time, Activity clock state, battery selection state, StateLayer ripple origins, and OSD vertical motion. Delegate computation was also moved out of `DropDownList`. The semantic report now has no active high- or medium-severity findings.

## Review rules

When changing QML:

1. Keep backend transport in `Shelllist.Io` or a domain backend component.
2. Keep controllers responsible for state transitions, not visual formatting.
3. Put pure formatting and UI presentation decisions in testable JavaScript helpers; keep domain policy, system parsing and telemetry calculations in the owning Rust daemon. Consult the [boundary audit](daemon-boundary-audit.md) before extending an existing frontend calculation.
4. Prefer shared UI primitives when behavior is repeated across domains.
5. Preserve stable delegate identity and avoid replacing models for live updates.
6. Do not add polling when the daemon already exposes a subscription.
7. Bound any unavoidable UI timer and stop it while the relevant surface is inactive.
8. Respect `Theme.noAnimations` for nonessential motion.
9. Keep expensive effects small and local; do not add frame-driven decoration to the bar.
10. Document every lint suppression next to the framework limitation it addresses.

## Detail-page layout contract

Use the same geometry ownership rules in every tab (Applications, Wi-Fi,
Bluetooth, Clipboard, Battery, and Time & Weather):

- `DetailFlickable` places its direct children in a `Column`. Children supply
  their width and explicit or implicit height; the column alone owns their `y`.
  Never put `anchors.fill`, `centerIn`, `top`, `bottom`, or `verticalCenter` on
  these children. An initially visible invalid child can disable positioning
  even after it is hidden, breaking subsequent selections and scroll extents.
- To center content in a section, give an unanchored `Item` a height and anchor
  its **contents**, not the section itself. `DetailCard` provides such a slot.
  For text-only empty/loading/error sections, use `CenteredMessage` directly
  with `width: parent.width` and `height: Math.max(120, implicitHeight)`.
- `CenteredMessage` is deliberately anchor-free: it centers and wraps text
  within its assigned bounds, clipping overflow in constrained overlays.
  Overlay callers explicitly use `anchors.fill: parent`; a sized `Loader`
  supplies the bounds for loaded messages. Do not reintroduce parent anchors
  into the shared component.
- Within `ColumnLayout`/`RowLayout`, use `Layout.*` hints instead of anchors on
  managed children. Anchor the layout itself only when its parent is a plain
  content slot, not another positioner or layout.
- Prefer `DetailColumnCard` for content-sized cards. Its `implicitHeight`
  includes the layout, optional heading, and stable padding; use it directly
  or as a minimum (`height: Math.max(110, implicitHeight)`). Do not derive
  padding from the resulting height, or fill a card with text whose implicit
  height is simultaneously used to size that card. This avoids circular
  geometry dependencies (including the Bluetooth Services-card case).
- Keep tab footers outside scrollable content (`TabbedDetailsStack` or the
  Battery panel's enclosing layout). Hide inactive sections with `visible`,
  rather than leaving space or manually adjusting sibling positions.

`tst_detail_layout.qml` checks the shared message/column/layout/loader contract;
`tst_application_page_layout.qml` covers empty, populated, hidden, and scrolled
launcher transitions; `tst_detail_pages.qml` exercises the other detail pages
at multiple widths with layout warnings treated as failures. Battery's tab and
footer geometry remains covered by `tst_battery_tabs.qml`.

## Quality gates

Run the complete co-development gate before merging structural changes:

```sh
tests/check-sibling-boundary.sh
```

This checks current sibling Git worktrees, including tracked uncommitted changes,
without requiring lock updates. Git-add new source files first. It also rejects
vendored snapshot drift, rather than silently validating an older library. Use
`nix flake check --keep-going --no-update-lock-file` separately for reproducible
release validation; ordinary Nix commands do not automatically refresh local Git
pins.

Useful focused commands:

```sh
shelllist-qmllint qml/Shelllist/{Core,Io,Ui}/*.qml shell/*.qml activity/*.qml \
  bar/*.qml battery/*.qml bluetooth/*.qml clipboard/*.qml launcher/*.qml \
  wifi/*.qml wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
node tests/check-bar-presentation.js bar/Bar{Workspace,Media,Osd,Status}Presentation.js \
  qml/Shelllist/Core/Duration.js
node tests/check-flow-policies.js battery/BatteryFlow.js clipboard/ClipboardFlow.js
tests/run-qml-tests.sh
tests/run-runtime-smoke.sh
tests/run-performance-benchmarks.sh
tests/benchmark-resident.py --duration 20 --check
tests/benchmark-responsiveness.py --check
```

The deterministic policy benchmark emits qmlbench-compatible samples under
`target/performance/` and is part of `nix flake check`. The resident benchmark
is intentionally manual because it measures the installed Wayland session; run
it only with Shelllist hidden. It enforces budgets for host CPU, PSS, and bridge
thread counts without mutating UI state.

The responsiveness benchmark is also target-session-only and deliberately opens
each surface once cold (when possible) and once warm. The resident host records
shortcut/IPC request-to-first-frame, content incubation, Rust search, and first
model-chunk timestamps. The script reports median, p95, and maximum values and
enforces acknowledgement, warm-frame, and cold-content budgets. Use
`shelllist responsiveness` to inspect the latest sample without running the
complete scenario.

For an optional structural report, generate benchmark evidence first:

```sh
tests/run-performance-benchmarks.sh
qmlqualitylens measure all --config qmlqualitylens.config.json
```

Review the generated reachability, cleanup, hotspot, clone, locality, semantic, runtime-warning, and QML health reports together. Aggregate scores are directional; lint, tests, runtime behavior, and clear ownership boundaries take precedence over optimizing one metric.

## Measured refactoring checkpoint

Compared with `7794505`, using the same corrected Lens on both revisions:

- Production source LOC: 28,866 → 28,805; component effort sum: 38,208 → 38,049.
- Battery paint cyclomatic/cognitive complexity: 16/31 → 11/17; application
  series drawing: 5/9 → 3/2.
- Battery/application chart locality: 15/31 → 33/53.
- Normalized clone groups: 194 → 191 with expanded limits and no omitted windows
  or groups. Default Lens clone output remains partial.
- Unreachable component and unused-ID candidates: both zero. Removed the unused
  Fast Pair setup UI and its private controller path, not daemon contract fields.
- Total source LOC including the new pixel tests increases by 21; the overall
  heuristic score remains 86. No lint suppressions or thresholds were relaxed.

The Qt suite passes 196 cases/hooks (132 `test_` rows), with zero failures/skips.
Native lint, both parser oracles, offscreen runtime smoke, and the six focused
Nix checks for QML tests/lint, packaged imports, application resources, TypeScript
and daemon boundaries pass. Pixel tests preserve missing-data gaps and isolated
battery samples; existing forecast, hover and narrow-layout tests remain enabled.

The complete flake is still blocked by an app-daemon/framework API mismatch
(`OwnedTaskRegistry.insert/remove`), using the same daemon derivation at the
unmodified baseline. The lock rejects `--no-update-lock-file`; validation used
`--no-write-lock-file` without editing it. This is not successful locked/full
integration, and no sibling daemon was changed. Formatting drift, incomplete
coverage and the existing internal ApplicationSettingsPage resolution warning
remain visible rather than being suppressed.

Lens corrections during this trial cover explicit Component ID scopes, optional
access/nullish complexity, and singleton dependency/member-use evidence. Raw
comparison evidence is in the sibling Lens checkout's ignored
`target/shelllist-review/`; methodology is in its
`docs/shelllist-refactoring-trial.md`.

## Areas to watch

The largest controllers coordinate many legitimate workflows and deserve extra review when modified:

- Wi-Fi connection, prompt, advanced-profile, and sharing flows;
- Bluetooth discovery, pairing, per-device operations, and adapter settings;
- application lifecycle and resource-history refresh;
- shared popup focus and monitor recovery;
- provider model reconciliation.

Prefer extracting a cohesive state machine or service component over creating thin forwarding wrappers solely to reduce file size.
