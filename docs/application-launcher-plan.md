# Shelllist application launcher implementation plan

**Implementation status:** The v0.1 baseline is implemented in `app-daemon` and `launcher/`: desktop catalog and visibility, Hyprland grouping/focus, identifier-only actions, `app-api` contracts, the resident QML chooser, packaging, Home Manager services, and the temporary `SUPER+M` binding are complete. Stabilization, broader fixture coverage, native event-driven catalog updates, and the eventual `SUPER+SPACE` cutover remain.

## Objective

Replace the current `rofi-app-menu` with a resident, keyboard-first Shelllist launcher while preserving its useful behavior:

- visible desktop applications from XDG data directories;
- running applications before non-running applications;
- `Enter` focuses the most-recent instance or launches the application;
- `Right` opens the application's running instances and secondary actions;
- application icons, filtering, focused-workspace placement, and a floating fallback;
- safe launching through desktop-entry semantics rather than shell evaluation.

The implementation follows the existing Shelllist boundary: Rust owns system integration, identity, policy, validation, and effects; QML owns presentation, focus, navigation, and animation.

## Scope

### Version 1

- Desktop application discovery and launch.
- Correct XDG precedence and desktop visibility policy.
- Localized application metadata and search terms.
- Hyprland running-window discovery, grouping, MRU ordering, and focus.
- Explicit **Launch new instance** and desktop-defined actions.
- Unmatched running windows represented as focus-only groups, preserving current Rofi behavior.
- Resident popover, IPC wrapper, global shortcut, and floating mode.
- Live updates when installed applications or Hyprland windows change.
- Contract, Rust, QML, and end-to-end tests.

### Deferred

- Arbitrary shell command execution (`rofi run`).
- Files, calculations, web search, and other launcher providers.
- Persistent frequency/usage learning.
- A generic window switcher independent of application grouping.
- Pinning/favorites and custom application editing.

The launcher should initially contain only the application provider, but its controller must use `ProviderRegistry` and `ResultStore` so other providers can be added later.

## Lessons from the current Rofi implementation

Preserve:

- XDG directory precedence and hidden-entry tombstones.
- Running-first empty-query ordering.
- Most-recent-window activation.
- Per-application instance navigation.
- Desktop-ID-based launch rather than executing `Exec` through a shell.

Do not carry forward:

- Tab-delimited parsing: empty `Icon` or `StartupWMClass` fields currently shift later fields.
- Partial visibility handling: `OnlyShowIn`, `NotShowIn`, and `TryExec` must be honored.
- Unconditional executable-basename matching: terminal wrappers and shared executables make it ambiguous.
- Silent launch/focus failures.
- Suppressing the ability to launch another instance of a running application.

## Architecture

Create a sibling Rust repository named `app-daemon`, following `nm-daemon`, `bt-daemon`, and `clip-daemon`:

```text
app-daemon/
  src/
    api.rs                 app-api dispatch and validated request types
    backend.rs             ApplicationBackend trait and error taxonomy
    catalog.rs             desktop application catalog and revisions
    client.rs              JSONL-to-D-Bus bridge
    daemon.rs              session D-Bus service and subscriptions
    desktop.rs             desktop metadata/visibility adapter
    fake.rs                deterministic test backend
    hyprland.rs            client snapshots, event subscription, focus dispatch
    identity.rs            window-to-application resolution
    launch.rs              safe desktop application/action launching
    model.rs               serializable summaries and operation outcomes
    protocol.rs            app-api v1 registry and fixture
    main.rs                daemon/client/debug commands
```

Add a launcher frontend to Shelllist:

```text
shelllist/launcher/
  AppApi.js
  ApplicationBackend.qml
  ApplicationContent.qml
  ApplicationController.qml
  ApplicationDetails.qml
  ApplicationListPane.qml
  ApplicationListRow.qml
  ApplicationProvider.qml
  shell.qml
```

Use the existing shared stack:

- `Shelllist.Io.JsonlDaemonClient` for transport and retry behavior;
- `Shelllist.Core.Provider`, `ProviderRegistry`, and `ResultStore` for results/actions;
- `ChooserController`, `ChooserSurface`, `ChooserWindowHost`, and shared list/detail controls;
- the current theme, density, focus-grab, screenshot, IPC, and floating-window behavior.

## Rust ownership

### Desktop catalog

Prefer `gio-rs`/`GDesktopAppInfo` for desktop-entry loading and execution because it already implements desktop launch semantics, field codes, activation, working directories, terminal handling, and desktop actions. Start with a short compatibility spike against the pinned Nixpkgs/GLib version. If its enumeration API does not expose enough metadata or precedence behavior, use `freedesktop-desktop-entry` for catalog parsing while retaining GIO for launch.

The catalog must:

1. Resolve XDG application directories in specification order.
2. Derive desktop IDs correctly, including entries in subdirectories.
3. Apply first-ID-wins precedence, including `Hidden=true` tombstones.
4. Enforce `Type=Application`, `NoDisplay`, `OnlyShowIn`, `NotShowIn`, and `TryExec`.
5. Select localized `Name`, `GenericName`, `Comment`, and `Keywords` using the current locale fallback chain.
6. Expose icon, categories, startup class, and desktop actions.
7. Never expose `Exec` or arbitrary command text to QML.
8. Maintain an in-memory immutable snapshot with a monotonic catalog revision.

Use GIO's application monitor where practical; otherwise watch resolved XDG application directories with `notify`. Debounce bursts and atomically replace the catalog snapshot.

### Hyprland adapter

- Read `hyprctl clients -j` into typed structures for the initial snapshot.
- Subscribe to Hyprland's event socket and debounce relevant events before rebuilding the client snapshot.
- Reconnect with bounded backoff after compositor restarts.
- Treat malformed clients as individual invalid records rather than dropping the complete snapshot.
- Keep raw window addresses inside Rust. QML receives opaque, lifecycle-scoped window IDs.
- Revalidate the window against the current snapshot immediately before focus.
- Focus through the current Lua dispatcher first and the legacy `focuswindow` dispatcher as fallback, matching `clip-daemon` compatibility behavior.
- Degrade to launch-only behavior when Hyprland is unavailable.

### Application identity policy

Resolve windows in this order:

1. exact desktop ID/app ID match, with an optional `.desktop` suffix removed;
2. exact case-insensitive `StartupWMClass` match against current and initial class;
3. explicit configured aliases;
4. no match.

Do not infer identity from an executable basename by default. It is ambiguous for Ghostty wrappers, Flatpak, Electron, browsers, and shared launchers.

Add unique identities to the local desktop entries:

- Yazi: launch with class `com.laufan.yazi` and declare the same `StartupWMClass`.
- Pi: launch with class `com.laufan.pi` and declare the same `StartupWMClass`.

Support optional aliases in `$XDG_CONFIG_HOME/app-daemon/config.toml` for third-party entries that cannot be fixed:

```toml
[identity."example.desktop"]
classes = ["example", "com.example.App"]
```

If no application matches, group windows by normalized initial/current class into a synthetic, focus-only result. Keep this representation inside the application provider for Rofi parity; a later window provider may replace it.

### Query and ranking policy

Rust supplies canonical metadata and an empty-query score:

1. focused application;
2. other running applications ordered by Hyprland focus history;
3. non-running applications, tied for alphabetical ordering in `Core.Model`;
4. unmatched focus-only groups alongside other running applications.

QML's existing `Core.Model.rankResults` remains responsible for generic textual matching. This is an acceptable UI concern and avoids introducing a second incompatible ranking contract. Populate result keywords with localized generic name, comment, keywords, categories, desktop ID, startup class, and instance titles.

Do not persist usage history in v1. Add it later only with a documented retention/privacy policy and deterministic score bounds.

### Execution policy

Expose identifier-based actions only:

- `activate`: focus the most-recent live instance, otherwise launch;
- `launch`: always request a new application instance;
- `focus-window`: focus one validated live window;
- `desktop-action`: invoke one action declared by the current desktop entry.

The daemon must resolve IDs against current state and reject stale or missing targets. Never accept a command line from QML. Return structured operation outcomes and preserve stderr internally for diagnostics without leaking arbitrary command content into normal UI payloads.

## app-api v1

Use the existing D-Bus plus JSONL bridge pattern:

- bus: `org.laufan.AppDaemon`
- object: `/org/laufan/AppDaemon`
- interface: `org.laufan.AppDaemon1`
- envelope: `app-api`, version `1`

### Methods

```text
applications.query
applications.refresh
applications.execute
```

`applications.query` parameters:

```json
{
  "query": "term",
  "generation": 4,
  "limit": 500
}
```

The query response contains a combined revision and application summaries. A summary has this conceptual shape:

```json
{
  "id": "org.example.App.desktop",
  "revision": 12,
  "kind": "desktop-application",
  "name": "Example",
  "generic_name": "Text Editor",
  "comment": "Edit text files",
  "icon": "org.example.App",
  "keywords": ["editor", "text"],
  "categories": ["Utility"],
  "startup_class": "org.example.App",
  "running": true,
  "focused": false,
  "running_count": 2,
  "instances": [
    { "id": "window-a1", "title": "notes.txt", "workspace_id": "2", "focused": false }
  ],
  "desktop_actions": [
    { "id": "new-window", "name": "New Window", "icon": "" }
  ],
  "score": 10990
}
```

`applications.execute` parameters:

```json
{
  "target_id": "org.example.App.desktop",
  "action": "activate",
  "window_id": null,
  "desktop_action_id": null,
  "expected_revision": 12,
  "workspace_id": "2"
}
```

Keep `workspace_id` as non-authoritative context for future launch placement. The daemon must not trust it for identity or authorization.

### Streams

```text
applications.changed
windows.changed
applications.operation
```

Change events carry revisions and reasons, not full snapshots. The QML controller coalesces them and requeries. Operation events/results carry request ID, action, target ID, status, and a user-safe message.

Generate `launcher/AppApi.js` and `contracts/app-api-ui-contract.fixture.json` from the daemon protocol registry, using the same drift check as the existing daemon integrations.

## QML behavior

### Provider

`ApplicationProvider.qml` maps daemon summaries to normalized results:

- provider ID: `applications`;
- result ID: daemon target ID;
- title: localized application name;
- subtitle: running count/workspaces, otherwise generic name or comment;
- icon: desktop icon;
- badges: `running`, `focused`, or `window`;
- score: daemon-provided empty-query score;
- preview kind: `application`;
- payload: the validated daemon summary.

Resolve actions dynamically in `actionsFor(result)` so stale snapshots do not determine enabled state. Use safe normalized QML action IDs and map them back to daemon window/desktop-action IDs inside the provider/controller boundary.

### Controller and execution lifecycle

`ApplicationController.qml` should:

- open a daemon session and query immediately on activation;
- debounce typed backend queries while allowing `ResultStore` to filter the current snapshot immediately;
- preserve selection by stable result key across window/catalog updates;
- route every action through `ProviderRegistry.execute`;
- show operation failures without closing;
- close only after successful focus/launch acceptance;
- cancel superseded queries and ignore stale generations;
- stop subscriptions/client work when the non-resident floating UI exits.

Before using close policies, extend `ProviderRegistry` to forward provider `executionStarted`, `executionFinished`, and `executionFailed` signals. This avoids application-specific action lifecycle shortcuts and makes the generic contract complete.

### UI and keys

Main list rows show icon, name, optional generic name, and a running/focused indicator. The detail pane shows application metadata, running instances with workspace labels, **Launch new instance**, and desktop actions.

Keyboard behavior:

```text
Type          filter
Down / Up     move selection
Enter         activate (focus MRU or launch)
Shift+Enter   launch new instance
Right         open instances/actions
Left          close details
Escape        close details, then launcher
F5            refresh catalog and windows
```

Mouse behavior follows the existing chooser convention: single-click selects, double-click activates, and the chevron opens details.

## Packaging and deployment

1. Add `app-daemon` as a Shelllist flake input and runtime dependency.
2. Add `packages.<system>.launcher` and `apps.<system>.launcher`.
3. Copy `launcher/` into `shelllistConfig` and include it in `qmllint`.
4. Add a `shelllist-launcher` wrapper with `daemon`, `foreground`, `floating`, `toggle`, `open`, `hide`, and `status`, matching the other chooser wrappers.
5. Install `app-daemon` as a graphical-session user service with restart-on-failure.
6. Run the resident Shelllist launcher frontend for warm startup, or have the wrapper ensure it is running before IPC.
7. Add Home Manager shims for `app-daemon` and `shelllist-launcher`.
8. During stabilization, bind a temporary key to Shelllist and keep `SUPER+SPACE` on Rofi.
9. After parity testing, move `SUPER+SPACE` to `shelllist-launcher toggle`; retain `rofi-app-menu` as an explicit fallback for one release.
10. Remove Rofi launcher wiring only after the rollback period. Clipboard can remain on its dedicated Shelllist shortcut; arbitrary `run` mode is explicitly not part of launcher v1.

## Delivery phases

### Phase 0 — dependency and behavior spike

- Validate GIO enumeration, visibility, localization, launch, and desktop actions on NixOS.
- Validate Hyprland event-socket reconnect behavior and Lua/legacy focus dispatch.
- Capture a sanitized fixture from the current installed desktop entries and client shapes.

Exit: chosen libraries and launch strategy are recorded, with no manual `Exec` parsing in the proposed path.

### Phase 1 — Rust catalog and app-api skeleton

- Create `app-daemon` with the standard daemon/client/debug layout.
- Implement desktop catalog, visibility, models, fake backend, query, refresh, revisions, and contract fixture.
- Implement safe application and desktop-action launch.

Exit: daemon tests cover catalog correctness and `applications.query/refresh/execute`; the JSONL client passes contract tests.

### Phase 2 — running windows and identity

- Add Hyprland snapshots, event subscription, reconnect/backoff, identity resolution, unmatched groups, and focus.
- Add local Pi/Yazi classes and optional alias configuration.
- Emit debounced application/window change streams.

Exit: current Zen, Ghostty, Scratchpad, Pi, and Yazi windows group correctly; stale focus IDs fail safely.

### Phase 3 — Shelllist launcher UI

- Complete generic provider execution lifecycle forwarding.
- Add launcher backend, provider, controller, list, details, shell, keys, and status/error states.
- Add provider and controller QML tests.

Exit: keyboard and mouse workflows match the Rofi baseline, with launch-new and visible errors added.

### Phase 4 — packaging and stabilization

- Add flake packages/checks, wrapper, user services, Home Manager shims, and temporary binding.
- Measure warm open-to-results and query update latency.
- Run daily use with Rofi fallback and inspect daemon/UI journals.

Suggested warm targets on the current machine:

- toggle-to-first-render: under 100 ms;
- typed-query visible update: under one frame from cached results;
- daemon requery after debounce: under 50 ms for the installed catalog;
- no process spawn per keystroke.

Exit: one week without incorrect grouping, missed application updates, launch regressions, or focus failures.

### Phase 5 — cutover

- Bind `SUPER+SPACE` to Shelllist.
- Update Shelllist README status, usage, architecture, and keybindings.
- Keep a documented `rofi-app-menu` fallback for one release, then remove its package/config if no longer needed.

## Test matrix

### Rust

- empty optional desktop fields;
- duplicate IDs and hidden higher-precedence tombstones;
- `NoDisplay`, `OnlyShowIn`, `NotShowIn`, and unavailable `TryExec`;
- locale fallback and escaped desktop values;
- nested desktop IDs and malformed files;
- duplicate executables without accidental matching;
- startup class, aliases, case handling, and unmatched windows;
- MRU ordering and focused result precedence;
- Hyprland malformed JSON, event bursts, disconnect/reconnect, stale addresses, and dispatch fallback;
- launch, desktop action, stale revision, cancellation, and safe error envelopes.

### QML/JavaScript

- application summary-to-result mapping;
- dynamic primary and secondary actions;
- query generations and stale-batch rejection;
- selection retention during live updates;
- close only on successful execution;
- error status and retry behavior;
- instance navigation and all keyboard shortcuts;
- empty, daemon-unavailable, Hyprland-unavailable, and launch-only states.

### Integration

- compare visible application IDs with a standards-compliant GIO/Rofi baseline;
- launch every selected test desktop entry without shell interpretation;
- focus single and multiple instances across workspaces;
- install/remove a desktop entry while the launcher is open;
- restart Hyprland and `app-daemon` independently;
- run both resident popover and one-shot floating modes;
- verify icon names and absolute icon paths.

## Main risks

- **Desktop-entry semantics:** mitigate by delegating parsing/launch to GIO where possible and retaining fixture tests.
- **Window identity ambiguity:** use explicit IDs/startup classes/aliases; never pretend ambiguous executable matches are reliable.
- **Compositor coupling:** isolate Hyprland behind `ApplicationBackend` and retain launch-only degradation.
- **Duplicate ranking logic:** keep textual ranking in `Core.Model`; Rust supplies only canonical metadata and base score.
- **Premature UI close:** close on successful backend outcome, not merely action dispatch.
- **Scope expansion into an omni-launcher:** ship application parity first; add providers independently after cutover.
