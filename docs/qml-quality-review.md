# QML quality and maintenance

Shelllist treats `qmllint`, QML tests, JavaScript policy tests, daemon-contract checks, and the Nix build as authoritative. `qmlqualitylens` is an additional structural review tool; generated reports live under `target/` and are not a release contract.

## Current structure

The UI is divided by ownership rather than by screen size:

- `shell/` owns the resident host, surface registry, IPC, and monitor-local bar creation.
- `bar/` owns bar and OSD presentation only.
- `launcher/`, `wifi/`, `bluetooth/`, and `clipboard/` own domain-specific controllers and views.
- `Shelllist.Core` owns provider contracts, normalization, ranking, and keyed result models.
- `Shelllist.Io` owns daemon transport and process boundaries.
- `Shelllist.Ui` owns theme tokens, windows, chooser layout, controls, state layers, elevation, details, prompts, and navigation.

Rust daemons remain responsible for system parsing, identity, validation, policy, and effects. QML should not grow alternate compositor, NetworkManager, BlueZ, PipeWire, process, or clipboard parsers.

## Maintained design decisions

- One `shell/shell.qml` host replaces per-surface Quickshell processes.
- Wi-Fi and Bluetooth load eagerly; Applications and Clipboard load on demand and remain warm.
- `ChooserShortcuts` centralizes Escape, refresh, and details-tab shortcuts.
- `ResultStore` reconciles one persistent keyed model instead of replacing ListView models.
- Providers resolve dynamic actions at use time rather than copying actions into recurring snapshots.
- `BarContent` renders normalized status descriptors through one delegate.
- Workspace, focused-window, media, tray, and OSD presentation are isolated components.
- `StateLayer` and `Elevation` centralize interaction feedback and depth.
- Operation lifecycle policy is kept in small JavaScript helpers where it can be tested without a running shell.
- Terminal backend events are correlated by request/operation IDs before changing UI state.

## Review rules

When changing QML:

1. Keep backend transport in `Shelllist.Io` or a domain backend component.
2. Keep controllers responsible for state transitions, not visual formatting.
3. Put pure formatting and policy in testable JavaScript helpers.
4. Prefer shared UI primitives when behavior is repeated across domains.
5. Preserve stable delegate identity and avoid replacing models for live updates.
6. Do not add polling when the daemon already exposes a subscription.
7. Bound any unavoidable UI timer and stop it while the relevant surface is inactive.
8. Respect `Theme.noAnimations` for nonessential motion.
9. Keep expensive effects small and local; do not add frame-driven decoration to the bar.
10. Document every lint suppression next to the framework limitation it addresses.

## Quality gates

Run the complete gate before merging structural changes:

```sh
nix flake check
```

Useful focused commands:

```sh
shelllist-qmllint qml/Shelllist/{Core,Io,Ui}/*.qml shell/*.qml bar/*.qml \
  bluetooth/*.qml clipboard/*.qml launcher/*.qml wifi/*.qml \
  wifi/networkinput/*.qml wifi/process/*.qml
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
node tests/check-bar-presentation.js bar/BarPresentation.js
tests/run-qml-tests.sh
```

For an optional structural report:

```sh
qmlqualitylens measure all --config qmlqualitylens.config.json
```

Review the generated hotspot, clone, locality, semantic, runtime-warning, and QML health reports together. Aggregate scores are directional; lint, tests, runtime behavior, and clear ownership boundaries take precedence over optimizing one metric.

## Areas to watch

The largest controllers coordinate many legitimate workflows and deserve extra review when modified:

- Wi-Fi connection, prompt, advanced-profile, and sharing flows;
- Bluetooth discovery, pairing, per-device operations, and adapter settings;
- application lifecycle and resource-history refresh;
- shared popup focus and monitor recovery;
- provider model reconciliation.

Prefer extracting a cohesive state machine or service component over creating thin forwarding wrappers solely to reduce file size.
