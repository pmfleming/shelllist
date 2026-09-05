# Daemon frontend commonality

Shelllist uses one frontend integration shape for Wi-Fi, Bluetooth, clipboard, applications, and the top bar while leaving domain policy in the owning adapter and controller.

## Endpoint contract

Each domain API module exports the same endpoint fields:

- `protocol` and `version` identify compatible envelopes;
- `methods` provides semantic aliases backed by generated daemon protocol bindings;
- `streams` provides semantic stream aliases;
- `subscribedStreams` states the resident subscription policy for that surface.

`DaemonBackend` consumes those fields through one endpoint descriptor and is the common transport-facing component. It owns shared-session attachment, pending request accounting, cancellation, generated request IDs, response compatibility checks, event-envelope validation, stream dispatch, and event-gap detection. Wi-Fi, Bluetooth, clipboard, applications, and the top bar therefore bind one `endpoint` instead of cloning four transport properties. Domain backends only provide request parameters, response application, and recovery actions.

A daemon event with an incompatible identity or malformed stream/event shape is rejected once at this boundary. A `lagged` event or `data.resync_required` marker becomes `eventGapDetected`; each adapter then requests the cheapest authoritative domain snapshot. Event-before-response ordering remains a daemon transport guarantee rather than frontend recovery logic.

## Shared chooser composition

Wi-Fi, Bluetooth, clipboard, and application surfaces use `ProviderChooserController` and the provider/result contracts. `ProviderChooserSurface` owns their default navigation, refresh, detail-tab, and help policy; a domain overrides only the constraints unique to its workflow. Wi-Fi, Bluetooth, and applications additionally opt into shared clipboard screenshot capture. Clipboard keeps its own screenshot operation because capture is part of its active domain operation and session state machine.

The top bar and its Activity and Battery surfaces use the same `DaemonBackend` primitives even though they are not search providers. Their requests use common sequencing and share the single `bar-daemon` session.

## Deliberate domain differences

Common infrastructure does not interpret domain payloads. In particular:

- Wi-Fi keeps typed connection, secret, hotspot, VPN, and statistics transitions;
- Bluetooth keeps pairing and cancellable device-operation state;
- clipboard keeps history pagination, edit sessions, validated multi-entry deletion, and wipe confirmation;
- applications keep catalog generation, lifecycle operations, and resource history;
- the top bar keeps OSD and notification presentation.

These differences should remain in domain controllers or adapters rather than becoming switches in `DaemonBackend`.

## Validation

Protocol fixture checks, `tests/check-daemon-boundary.js`, and QML routing tests cover endpoint compatibility and shared-session behavior. Strict `qmllint` checks component integration. Common helper names and composition choices are review concerns, not source-token test contracts.
