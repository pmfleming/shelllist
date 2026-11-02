# Temporary workspace executable contract

The shared Rust types in `shelllist-daemon-core::workspace_wire` are the wire
contract for lifecycle protocol version 1. These are additive operations on the
existing authenticated bar/app session transports. Rust owners determine routing,
allocation, retirement, placement eligibility and recovery. QML renders state.

## Workspace strip presentation

Every workspace is a fixed-width, icon-only target. Standard destinations retain
their category icons; temporary destinations use their stable origin icon or the
shared workspace fallback icon. Names and IDs remain in the accessible label,
without inline origin text or number labels. This supersedes the implementation
plan's inline icon/number presentation. The fixed add button, divider, acknowledged
active state, occupancy/urgency cues and left-click routing remain unchanged.
Overflow reveals the active target and resets its scroll offset when the strip fits.

## Identity and admission

Every effect carries the exact compositor session and an immutable request key.
The key is at most 128 ASCII alphanumeric, hyphen or underscore characters.
The same key with changed parameters is rejected; a duplicate returns its
existing receipt. IDs are positive signed 32-bit compositor workspace IDs.
Allocation never wraps or reuses an ID during the compositor session.

`Context` captures session, invoking monitor and its active ordinary workspace.
`Create` distinguishes a landing pad from a launch reservation, and either
allocates a new workspace or leases an explicit destination. `Lease` binds the
request to a workspace generation. `Placement` identifies the exact new window
and follow intent. `Close` captures the source context; it cannot request a kill.
`Lookup` recovers a receipt using the original key, without replay.

## Compositor boundary

Use exact-session IPC only. Snapshot acquisition parses a complete synchronous
batch of monitors, workspaces and clients; failed acquisition is unknown.
Validate numeric and string input in Rust before constructing protocol expressions.
Check dispatch result `.ok`; a Lua result table is truthy even on failure.

Close pins weak compositor window references in the same batch as its target
snapshot, then persists admission before dispatch. The reference,
address, PID, mapped state and workspace must still match in the compositor event
turn that sends normal close. Consuming the reference prevents repeated dispatch
and distinguishes a recycled address in the same process. Reference tokens are
bounded and journaled by the Rust owner; the compositor stores only weak handles,
not lifecycle or routing policy. Never replay uncertain close dispatch on restart.

Local focus checks the captured monitor workspace and rejects a destination owned
by a different monitor. It never uses `on_current_monitor` to move/swap an occupied
foreign workspace. Background replacement restores prior monitor/window focus.
Follow remains conditional on the original captured focus intent.

## Recovery and delivery

Durably record admission before effects; preserve per-window close and per-launch
handoff uncertainty. Lost responses lead to lookup, never a replacement effect.
Bar serializes lease admission, placement and retirement; app proves launch
provenance. Old writer generations cannot perform placement after lease release.
Close admission revokes pending destination leases before its first close.
Indeterminate launch is distinct from success and failure.

An old app catalog without the `new_workspace` boolean exposes ordinary actions
only. An explicitly unsupported bar context protocol permits ordinary default
routing, while new/current overrides and saved-new routing require the matching
owner. Malformed replies and transport failures are not compatibility signals.

The action matrix, migration, monitor fallback and stage exits are specified in
[the implementation plan](temporary-workspaces-plan.md). Capability negotiation
must keep unqualified operations unavailable. Stage completion requires executable
tests and evidence under `tests/`, not just these declarations.
