# Daemon frontend commonality

Shelllist uses one frontend integration shape for Wi-Fi, Bluetooth, clipboard, applications, and the top bar. Domain policy belongs in the owning Rust daemon; frontend adapters/controllers own view intent, presentation, and applying replies. See the [boundary audit](daemon-boundary-audit.md) for remaining migrations.

## Endpoint contract

Each domain API module exports the same endpoint fields:

- `protocol` and `version` identify compatible envelopes;
- `methods` provides semantic aliases backed by generated daemon protocol bindings;
- `streams` provides semantic stream aliases;
- `subscribedStreams` states the resident subscription policy for that surface.

`DaemonBackend` is the common transport-facing component. Adapters bind typed `daemonName`, `expectedProtocol`, `expectedVersion`, and `streams` properties from their API modules; there is no untyped endpoint descriptor. It owns shared-session attachment, pending request accounting, cancellation, generated request IDs, response compatibility checks, event-envelope validation, stream dispatch, and event-gap detection. Domain backends provide request parameters, response application, and recovery actions.

Use `cancel(requestId)` for the shared default cancellation identity and `cancelWithId(requestId, cancellationId)` for an explicit identity. Do not use an omitted typed string argument as an optional parameter: Qt converts it to the literal `"undefined"`. Clipboard/application query and detail cancellation use the shared default directly; Bluetooth and clipboard operation cancellation retain their domain-specific IDs.

A daemon event with an incompatible identity or malformed stream/event shape is rejected once at this boundary. A `lagged` event or `data.resync_required` marker becomes `eventGapDetected`; each adapter then requests the cheapest authoritative domain snapshot. Event-before-response ordering remains a daemon transport guarantee rather than frontend recovery logic.

## Shared chooser composition

Wi-Fi, Bluetooth, clipboard, and application surfaces use `ProviderChooserController` and the provider/result contracts. `ProviderChooserSurface` owns their default navigation, refresh, and detail-tab policy; a domain overrides only the constraints unique to its workflow. Wi-Fi, Bluetooth, and applications additionally opt into shared clipboard screenshot capture. Clipboard keeps its own screenshot operation because capture is part of its active domain operation and session state machine.

`Core.Provider.makeResult(fields)` supplies provider identity/priority and common normalization without mutating the projection. Wi-Fi, Bluetooth, applications, displays and clipboard use it. `resultsFor(values)` maps through the overridable `resultFor(payload)` for the first four; clipboard retains its offset-aware history scoring. Actions, availability, payload fields and recovery stay domain-owned.

The top bar and its Activity and Battery surfaces use the same `DaemonBackend` primitives even though they are not search providers. Their requests use common sequencing and share the single `bar-daemon` session.

## Shared model and interaction ownership

`Core.KeyedListModel` reconciles stable keyed values for all four provider
choosers (through `ResultStore`) and for the bar. It owns incremental moves,
insertions/removals, bounded rebuild chunks and stale-work fencing. Consumers
own selection, search, payloads and presentation; the bar overrides `equivalent`
to retain its descriptor comparison without a second reconciliation algorithm.

`Ui.ActionControl` supplies guarded keyboard/accessibility activation for shared
buttons, tabs, toggles, action areas and bar actions. Bar secondary buttons and
wheel actions remain distinct. `ChooserListPane.requestRefresh()` and
`ResultRow.pick()` are explicit method contracts, not mutable function properties.
Domain overrides keep Bluetooth discovery, clipboard deletion/multi-selection
and application force-refresh behavior local.

`Core.SearchService` shares one lazy, typed `Io.SearchProcess` boundary for the
provider choosers. Provider prefixes are typed string lists and become ordinary
JavaScript arrays at descriptor normalization; JSON domain payloads remain dynamic.
Shared controls and the bar use `Ui.InteractiveBehavior` for decorative numeric
and color interpolation with explicit timing overrides. Spring motion remains
separate, and neither mechanism owns logical state or keyboard focus.

`Core.Model.settingToggle` shares normalized settings-toggle presentation for
Wi-Fi and Bluetooth; providers retain live capability and checked-state ownership.
`Ui.ActionDetailsPane.triggerAction` routes header intent to the chooser controller
by default. Clipboard overrides that method for its specialized actions, rather
than adding another dispatcher to the signal. Bar groups share theme color tokens
without changing their layout or interaction policy.

See the [latest measured review](reviews/lens-session-maintenance-2026-09-27.md),
[earlier keyboard review](reviews/lens-keyboard-maintenance-2026-09-27.md),
[previous endpoint review](reviews/lens-commonality-2026-09-27.md) and
[original commonality review](reviews/commonality-2026-09-20.md) for evidence and limits.

## Deliberate domain differences

Common infrastructure does not interpret domain payloads. Domain daemons own
connection/device policy, validated mutations, edit leases, history consistency,
application lifecycle execution, and resource statistics. Frontend controllers
own the corresponding visible prompts, unsaved drafts, selection, requested
ranges, loading/error state, OSDs and notification presentation.

Do not move daemon-specific policy into `DaemonBackend` or the generic Rust
bridge. Existing frontend history orchestration/calculations are migration debt,
not an architectural requirement.

The Rust bridge carries typed request addresses and owns subscription-event
routing/cleanup. QML retains only live view handles and base-subscription
visibility intent, not per-request routing or subscription-owner dictionaries.

## Validation

Protocol fixture checks, `tests/check-daemon-boundary.js`, and QML routing tests cover endpoint compatibility and shared-session behavior. Strict `qmllint` checks component integration. Common helper names and composition choices are review concerns, not source-token test contracts.
