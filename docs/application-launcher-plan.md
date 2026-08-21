# Application launcher

The Shelllist application launcher is implemented by `launcher/` and the sibling `app-daemon` repository. This document describes the current boundary and behavior; it is no longer a delivery plan.

## User behavior

The launcher presents standards-visible desktop applications and live Hyprland windows in one ranked list.

- `Enter` focuses the most-recent running instance or launches a non-running application.
- `Shift+Enter` launches another instance of a desktop application.
- `Right` opens application details, running instances, close actions, and desktop actions.
- `Ctrl+Tab` switches between Application and Resources details.
- `F5` refreshes the catalog and current windows.
- Launch-only desktop entries remain shortcuts without runtime state or resource attribution.

Empty queries put focused and running applications before launch-only results. Typed queries use daemon match scores and the shared provider model. Selection is retained by stable result key when snapshots change.

## Ownership

### `app-daemon`

Rust owns:

- XDG desktop catalog precedence, visibility, localization, and revisions;
- safe desktop-entry, desktop-action, and terminal launch semantics;
- Hyprland window discovery, application identity, MRU ordering, focus, move, and close effects;
- stale-target and expected-revision validation;
- asynchronous operation lifecycle events;
- process/cgroup resource attribution and 24-hour resource history.

The daemon exposes `app-api` v1 over session D-Bus and its JSONL client. Shelllist sends identifiers, never shell command text or raw Hyprland addresses.

### Shelllist

QML owns:

- filtering and list/detail presentation;
- keyboard and pointer navigation;
- provider/action mapping;
- operation progress and error presentation;
- popup close policy;
- current-workspace launch context;
- compact 30-minute resource graphs.

The frontend does not parse desktop files, process tables, cgroups, or compositor JSON.

## Frontend structure

| File | Responsibility |
| --- | --- |
| `ApplicationBackend.qml` | Shared JSONL transport calls and event routing |
| `ApplicationController.qml` | Query generations, selection, lifecycle, history, and UI state |
| `ApplicationProvider.qml` | `app-api` summary/action mapping to `Shelllist.Core` |
| `ApplicationPresentation.js` | Pure formatting and result-transition helpers |
| `ApplicationLifecycle.js` | Safe operation correlation and revision handling |
| `ApplicationListPane.qml` / `ApplicationListRow.qml` | Ranked application list |
| `ApplicationDetails.qml` | Application/Resources/Settings tab shell |
| `ApplicationPage.qml` | Metadata and top-level actions |
| `ApplicationInstanceList.qml` | Per-window focus and close actions |
| `ApplicationDesktopActions.qml` | Desktop-defined actions |
| `ApplicationResourcesPage.qml` | Current resource cards and history graphs |
| `ApplicationSettingsPage.qml` | Combined category and default-workspace selection |

The launcher uses `ProviderRegistry`, `ResultStore`, and the generic chooser components. It is loaded on first use by `SurfaceRegistry` and remains warm afterward.

## API use

Shelllist consumes these methods:

```text
applications.query
applications.history
applications.refresh
applications.execute
applications.settings.update
```

and these streams:

```text
applications.changed
windows.changed
applications.operation
```

Queries are generation-scoped and can select one of the five app categories. Superseded results are ignored and cancellable backend work is cancelled. Catalog, settings, and window change events trigger a coalesced requery instead of carrying complete snapshots.

Category overrides are persisted by `app-daemon` and map directly to default workspaces 1–5. Execution requests contain only a target ID, normalized action, optional window or desktop-action ID, a JavaScript-safe expected revision, and non-authoritative workspace context. The daemon resolves every identifier against current state before applying an effect, applies the category's saved workspace preference, and moves the newly created window without disturbing existing instances.

## Operation lifecycle

Application execution is asynchronous:

1. Shelllist dispatches an action and keeps the chooser open.
2. `app-daemon` returns an accepted operation ID.
3. `applications.operation` reports running and terminal state.
4. Successful focus/launch actions close the chooser; close actions update the visible result in place.
5. Failures remain visible and leave the chooser usable.

A 20-second frontend watchdog clears uncertain state and requeries if a terminal event is lost. Unsafe integer revisions are omitted rather than rounded by JavaScript.

## Resources

While the launcher is visible, the controller refreshes current metrics every two seconds. Opening Resources requests the latest 30 minutes of history and refreshes it every 15 seconds.

The UI presents only capabilities reported by the daemon. Depending on attribution support, this can include CPU, proportional or resident memory, GPU activity/memory, physical and logical I/O, permanent and temporary application data, process/thread counts, file footprint, and estimated energy. Missing capabilities are not synthesized in QML.

## Intentional limits

The current launcher is not an omni-launcher. It does not provide arbitrary command execution, file search, calculations, web search, usage-frequency learning, favorites, or desktop-entry editing. Window identity remains explicit and conservative; ambiguous executable-name guesses are not treated as application identity.

## Validation

The checked frontend fixture is `contracts/app-api-ui-contract.fixture.json`. Relevant checks include:

```sh
node tests/check-application-presentation.js launcher/ApplicationPresentation.js
node tests/check-application-lifecycle.js launcher/ApplicationLifecycle.js
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
tests/check-app-api-contract.sh
tests/run-qml-tests.sh
```

The authoritative backend behavior and resource semantics are documented in the sibling `app-daemon` README and tested in that repository.
