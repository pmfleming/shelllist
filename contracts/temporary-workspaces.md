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

Manually created workspaces remain logical destinations until an explicit
workspace close, even after switching away, becoming empty or restarting the
owner. Hyprland may reclaim the empty inactive object; the journal preserves
its ID, generation, monitor and strip entry so focus/move can materialize it
again. Native numeric shortcuts address IDs 1–9 and 10 via 0; Shift adds move
and follow. Higher IDs remain accessible through the strip and previous/next.
Launch-created workspaces retain automatic retirement after their windows and
leases settle. External workspaces retain compositor-owned lifetime rules.

An occupied launch-created workspace must remain empty for two seconds before
automatic retirement. A new window cancels that interval; explicit workspace
close bypasses it. A scheduled owner wake ensures cleanup completes even when
no further compositor events arrive. Unknown snapshots never prove emptiness.

The owner preserves the verified first placement across same-process window
replacement (for example an Electrum login window becoming the wallet window).
It captures PID plus process start time and a weak compositor reference during
initial placement. When that exact window disappears, one unambiguous new window
from the same process may inherit its destination within two seconds of observed
disappearance, even if the user has switched workspaces. Replacement placement
never follows focus. Windows observed alongside the predecessor are excluded;
matching by application class, title, or a recycled address alone is insufficient.
Cross-process successors are deliberately not inferred from shared application
identity. This adds no public wire fields or frontend navigation behavior.

Tracking is limited to fresh launch-created destinations, 128 concurrent launch
observers and eight replacements per observer. Login time while a window remains
open is unlimited; the grace period starts at disappearance. Manual window
movement, explicit workspace close, another explicit placement from that process,
process exit/PID reuse, ambiguous successors, identity loss, compositor event
disconnect/config reload, and owner restart fence replacement intent. Admission
is durable before each move; uncertain moves are not replayed. Releasing the
original launch lease still fences further caller placement, while the separately
recorded owner observer may finish this bounded same-process handoff.

The private journal's additive `keep_until_closed` flag defaults false. Older
manual entries migrate using their original reservation and generation, unless
a close was already admitted. Explicit close durably clears retention with
lease revocation before sending any normal window close; a pending close cannot
readopt an empty destination as a landing pad.

An old app catalog without the `new_workspace` boolean exposes ordinary actions
only. An explicitly unsupported bar context protocol permits ordinary default
routing, while new/current overrides and saved-new routing require the matching
owner. Malformed replies and transport failures are not compatibility signals.

The action matrix, migration, monitor fallback and stage exits are specified in
[the implementation plan](temporary-workspaces-plan.md). Capability negotiation
must keep unqualified operations unavailable. Stage completion requires executable
tests and evidence under `tests/`, not just these declarations.
