# Provider model

Shelllist surfaces share a normalized provider/result/action model. Generic views render results and dispatch stable action IDs; provider adapters translate those values to domain-daemon requests.

## Rules

1. Providers own capabilities and execution. Generic views never call domain backends.
2. Results and actions are serializable values, not callbacks.
3. Display text is never identity. Result keys are derived from provider and result IDs.
4. Provider payloads are private to their provider and controller.
5. Boundary data is normalized and validated by `qml/Shelllist/Core/Model.js`.
6. Providers resolve live actions immediately before rendering or execution.
7. Queries are generation-scoped; stale batches are rejected.
8. Destructive actions declare confirmation intent, but providers still own validation and effects.
9. Secrets never appear in results, metadata, query context, command lines, or logs.
10. Backends must revalidate identifiers and state before applying an effect.

## Components

- `Provider.qml` defines the adapter interface and execution signals.
- `ProviderRegistry.qml` validates descriptors, resolves providers, and dispatches actions.
- `ResultStore.qml` owns source results, query generations, ranking, and the visible model.
- `Model.js` normalizes descriptors/results/actions and performs generic text ranking.
- `ProviderChooserController.qml` connects a provider and result store to shared chooser behavior.

`ResultStore.visibleResults` is the ranked provider-neutral array. `visibleModel` is a persistent keyed `ListModel`; snapshots are reconciled with insert/move/update/remove operations so recurring backend changes do not recreate every delegate.

## Provider descriptor

```js
{
  schemaVersion: 1,
  id: "wifi",
  name: "Wi-Fi",
  icon: "…",
  priority: 100,
  enabled: true,
  prefixes: ["wifi:"],
  capabilities: {
    query: false,
    actions: true,
    preview: true,
    subscriptions: true
  },
  metadata: {}
}
```

Provider IDs match `[a-z0-9][a-z0-9._-]*`.

## Result

```js
{
  schemaVersion: 1,
  providerId: "applications",
  providerPriority: 100,
  id: "org.example.App.desktop",
  key: "applications::org.example.App.desktop",
  title: "Example",
  subtitle: "Text editor",
  icon: "org.example.App",
  score: 120,
  keywords: ["editor", "utility"],
  badges: ["running"],
  primaryActionId: "activate",
  actions: [],
  preview: { kind: "application", available: true },
  state: { active: false, busy: false },
  payload: {},
  metadata: {}
}
```

`id` is stable within one provider. `key` is generated globally. `payload` may contain the daemon summary but must not be interpreted by generic views.

Providers with dynamic state normally leave `actions` empty and implement `actionsFor(result)`. This avoids normalizing duplicated action objects on every scan or resource snapshot.

## Action

```js
{
  schemaVersion: 1,
  id: "launch",
  label: "Launch",
  icon: "…",
  shortcut: "Enter",
  role: "default",             // default | secondary | destructive
  kind: "command",             // command | toggle
  enabled: true,
  visible: true,
  closePolicy: "close",        // provider-default | close | keep-open
  confirmation: {
    required: false,
    title: "",
    message: ""
  },
  state: { checked: false },
  presentation: {
    group: "primary",          // primary | toolbar | settings | overflow
    tone: "active",            // normal | active | danger | warning
    width: 140
  },
  metadata: {}
}
```

The registry fetches current actions and rejects hidden or disabled actions before calling `execute`. Semantic fields such as role, kind, confirmation, and close policy remain separate from visual placement and tone.

Details use one visible primary header action. Secondary actions belong in the toolbar; settings and item-specific actions stay in their relevant content section.

## Queries

A query has a request ID, monotonic generation, text, limit, exact-match flag, selected providers, and non-secret context. Each batch belongs to exactly one provider:

```js
{
  providerId: "applications",
  queryId: "query-171234-4",
  replace: true,
  complete: true,
  results: []
}
```

Replacement and removal update source results first, rank once, then reconcile the visible model by stable key. Cross-provider batches, duplicate IDs, and inactive query IDs are rejected.

## Execution

```js
{
  id: "action-171234-8",
  providerId: "applications",
  resultId: "org.example.App.desktop",
  resultKey: "applications::org.example.App.desktop",
  actionId: "launch",
  result: {},
  action: {},
  context: { workspaceId: "2" }
}
```

The normalized result and action are included for adapter convenience. Routing still uses IDs, and Rust daemons remain authoritative for identity, stale-state checks, authorization, and effects.

## Current adapters

- `ApplicationProvider.qml` maps `app-api` catalog/window summaries and asynchronous operations.
- `WifiProvider.qml` maps `nm-api` network state and connection/profile actions.
- `BluetoothProvider.qml` maps opaque-keyed `bt-api` devices and operations.
- `ClipboardProvider.qml` maps `clip-api` history entries and clipboard actions.

All four use the same result store and chooser navigation while retaining independent backend protocols and domain-specific details views. New searchable domains should add a provider adapter instead of adding domain branches to generic UI components.

## Validation

```sh
node tests/check-provider-model.js qml/Shelllist/Core/Model.js
tests/run-qml-tests.sh
nix flake check
```

The QML tests cover provider registration, result-store reconciliation, query routing, and shared navigation. Checked daemon fixtures cover each external JSON boundary.
