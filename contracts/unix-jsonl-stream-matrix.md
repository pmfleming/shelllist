# Unix JSONL stream inventory and recovery gates

This is the current migration inventory, not a claim that every contract below
is implemented. See [implemented stages and evidence](unix-jsonl-stream-recovery.md).
The JSONL request/route/cancellation envelope is transport-independent. Domain
ordering metadata is additive and requires matched producer/consumer builds on
**both** the bridge and socket paths. Missing metadata never enables a weaker
frontend fallback. D-Bus remains supported.

## Ordering vocabulary

- **Transport generation:** fences replies and events from retired connections.
  A new connection receives a new server-minted owner; it cannot inherit old work.
- **Producer epoch:** identifies one authoritative publication lifetime. It is
  opaque, not sortable. Reset/rollover requires a new authoritative baseline.
- **State revision:** orders captured domain state within an epoch. State and its
  revision must be captured/published atomically, including unavailable state.
- **Delta base/next:** a delta applies only to its exact accepted base. Once the
  base is uncertain, suspend merges until a replacement subscription supplies a
  full baseline. An arbitrary RPC read is not such a baseline without a watermark.
- **Delivery sequence:** if used, sequence after owner/visibility filtering or
  represent omissions explicitly. Never infer loss from a content hash, request
  ID, global sequence filtered for another owner, or coalesced full replacement.

Full replacements may skip revisions and can recover directly to current state;
ordered transitions and deltas cannot. No recovery read may launch an effect.
Cancellation requests do not establish rollback or a terminal outcome. A fresh
owner must not gain access to private outcomes belonging to a retired owner.

## Stream matrix

“Open” is a rollout blocker, not an instruction to invent a generic retry loop.
RPC names below are existing unless explicitly marked as needed.

| Producer / streams | Class and current recovery | Open ordering / quiet-stream gate |
| --- | --- | --- |
| BT `bluetooth.changed`, `bluetooth.audio.changed` | Implemented: independent atomic `data.state` epoch/revision on watch values and cached reads, including loading/unavailable; explicit lineage for coalesced rollover. Frontend rejects stale reads/events and unwatermarked mutation observations. Explicit reads repair a lost final replacement without replay. | Full-state ordering is covered by native producer/Qt tests. Periodic liveness, release/load/OS-crash qualification and the separate lifecycle rows below remain open; no broader stream completion is implied. |
| BT `pairing.request` | Private prompt/lifecycle content on a bounded broadcast with explicit gaps; `bluetooth.requests.snapshot` includes active pairing requests. | Audit observation versus response authority, filtered owners, stale prompt recovery and expiration. Never redisplay a closed secret draft or answer a prompt during recovery. |
| BT `bluetooth.operation`, `bluetooth.scan` | Operation/lease lifecycle; explicit broadcast gaps; `bluetooth.requests.snapshot` exposes active/recent state. | Order status reads against transitions; preserve owner cancellation and terminal evidence. Lost final events require status recovery, not starting another operation/scan. |
| BT `bluetooth.obex.transfer` | Transfer lifecycle and incoming authorization; explicit broadcast gaps. | Audit authoritative transfer outcome recovery separately from capability reads (`bluetooth.obex.snapshot`). An absent recovery API is a blocker, not assumed completion or permission to resend a file. |
| NM `wifi.networks` | Initial full collection plus subscription-local epoch/base/next deltas; isolated collection renewal is implemented. | No global watermark on `wifi.networks` reads. Explicit refresh, scan completion/watchdog and warmup renew the collection; a silent final loss is not inferred from sequence alone. Keep secret/status observers and accepted operations alive during renewal. |
| NM `wifi.status`, `network.connectivity`, `network.inventory` | Immediate/changed full projections; corresponding reads exist. | Atomic snapshot/subscription and read/event ordering still require qualification. Define explicit refresh/reconnect behavior even when no later event exposes a loss. |
| NM `network.statistics` | Request-correlated sample stream. | Samples may have irrecoverable holes; mark discontinuities and reset rate baselines. Operation status must distinguish a dead watch from quiet traffic; never fabricate missing samples. |
| NM `hotspot`, `vpn`, `wifi.scan`, `wifi.connect`, `wifi.band` | Request-correlated operations; `operation.status` plus domain reads where applicable. | Qualify terminal retention, status/event races and final-event loss per operation. State observation is not proof of an uncertain effect's outcome; no recovery restart. |
| NM `network.health` | Per-consumer filtered historical feedback. | Filtering must not create false gaps. Reconnect may read current network state, but must not synthesize or replay missed health notifications. |
| NM `wifi.secret` | Private credential prompts/cancellation/delivery/persistence. | Audit current prompt/status recovery, expiry and authorization without exposing secrets to new owners. Collection renewal must not replace these observers. |
| NM `daemon.request`, `daemon.subscription` | Internal correlated cancellation acknowledgements; not subscribable. | Do not treat these as state streams or replay cancellations to fill a delivery hole. |
| App `applications.changed`, `windows.changed` | Implemented invalidation barrier: initial/change delivery fences older query/revision replies before debounced refresh. Content tokens are not delivery order. Fresh queries replace current state. | Actual Qt races and quiet-final-loss explicit refresh are covered. View warmup also reads current identity. Native direct reads/renewal pass; maximum payload, sustained load and startup/default acceptance remain separate. |
| App `applications.operation` | Implemented atomic per-operation revisions on reads/events, owner-filtered lifecycle and explicit upstream gaps; 256 terminal results retained up to 15 minutes. Frontend rejects stale observations and polls owned status, bounded to ten two-second checks, with explicit checks thereafter. | Quiet terminal read recovery, old-producer rejection, foreign ownership, unread acceptance cleanup and real private SIGKILL/restart are covered. Poll exhaustion/expiry, lost launch acknowledgement and retired owners remain explicitly uncertain, never relaunch. Release/load and maximum-payload acceptance remain open. |
| Bar `theme.changed`, `activity.changed`, `workspaces.changed`, `workarea.changed`, `compositor.changed`, `media.changed`, `audio.changed`, `brightness.changed`, `power-profile.changed`, `sleep-policy.changed`, `display-policy.changed`, `notifications.changed`, `updates.changed`, `timezone.changed` | Implemented atomic per-domain `_publication` on cached reads/events, including unavailable state and rollover lineage. Frontend rejects stale/duplicate/malformed observations and reconciles effect receipts separately. Explicit reads repair quiet final loss. | Deterministic producer/Qt evidence covers ordering, theme previews and retained drafts/effects/peers. Independent bar opt-in and private real-Quickshell reads/publication/renewal/peer-release now pass. Release/load, maximum payload, startup/default rollout and OS-process-crash gates remain open. |
| Bar `battery.changed`, `power-sleep.changed`, `notifications.active.changed`, `osd-hardware.changed` | Bounded transitions with atomic current-state watermarks. Discontinuities/reads become subscribed baselines, never reconstructed edges. Battery owned status polling and display acknowledgement/draft guards survive domain recovery/renewal. | Missed historical edges remain irrecoverable; no replay of OSD, sleep or notification effects. Current-state ordering does not prove uncertain terminal outcomes, rollback, installed-session or OS-crash acceptance. |
| Clip `clipboard.history.changed`, `clipboard.current.changed` | Reset/invalidation; event counter and separate history content token. `clipboard.history.query` and `.revision` recover collections. | Initial/reset/lag must have explicit ordering semantics. Fence old queries against resets; content tokens are not event watermarks. Final-loss refresh must preserve privacy and invalidate sensitive caches. |
| Clip `clipboard.capture.changed` | Capture lifecycle; settings reads recover configured pause state, not every active capture outcome. | Needed: authoritative owner-scoped active-capture/outcome recovery or explicit nonrecoverable uncertainty. Configuration is not proof of capture completion. |
| Clip `clipboard.operation`, `clipboard.session` | Operation/session lifecycle and explicit gaps. Producer sessions/edit leases/wipe challenges now have owner scope and D-Bus disconnect/late-registration cleanup; API lifecycle receipts are owner-filtered. | Needed: backend asynchronous operation ownership/delivery and authoritative status/terminal retention; no general wire operation-status method exists yet. Internal live-job reconciliation is not a public recovery API. Hidden acknowledgement stays single-use; release is not effect rollback. Preserve unknown outcomes; never republish or paste during recovery. |

## Required acceptance for each row

1. Exercise real producer serializers and actual Qt consumers with duplicate,
   missing, reordered, old-epoch and malformed records, not just mock transports.
2. Race RPC reads against initial subscription and live delivery. An old reply
   must not overwrite a newer accepted state. Validate shape before advancing a
   cursor; malformed payloads must not consume the only recoverable revision.
3. Exercise owner filtering, bounded lag and a lost final event with no later
   witness. Document the actual convergence trigger and its limits; sequence
   checks alone cannot detect quiet loss.
4. Disconnect before/after acknowledgement and during terminal delivery. Keep
   accepted-work accounting until completion and repeat idempotent owner cleanup
   after late acceptance. Reconnect establishes fresh state, never effect replay.
5. Preserve native domain guards, secret authorization, cancellation and explicit
   retry. Full-source matched-build checks and real Quickshell probes remain
   separate from deterministic Qt tests and release/load/process-crash acceptance.

## Source anchors and checkpoint

- BT: `src/daemon/{subscription,operation,scan,obex}.rs`, `src/protocol.rs`;
  Shelllist `bluetooth/BluetoothBackend.qml`.
- NM: `src/{protocol,daemon_status,daemon_event}.rs`,
  `src/daemon_status/network_updates.rs`, `src/daemon_runtime/subscriptions.rs`.
- App: `src/daemon.rs`, `src/daemon/events.rs`, `src/protocol/methods.rs`.
- Bar: `src/daemon/subscriptions.rs`, `src/state/events.rs`, `src/protocol/read_wire.rs`.
- Clip: `src/protocol.rs`, `src/daemon/subscription.rs`, `src/api.rs`.

Producer paths are relative to their sibling repository. Audited against framework
`563e7f9`, BT `ecf65fc`, NM `0396f00`, app `2bf19d6`, bar `ba04a15`, clip `2c2cef3`
and Shelllist `80b4662`. BT full-state ordering subsequently landed in `962f5ee`
and `3e0ecb4`, with matched frontend fencing in the linked recovery record.
App ingress/recovery landed in producer `bb013f1` and frontend `a1971f2` as scoped
above. Bar producer `360bcbf` adds shared ingress and transport-owned cancellation,
but does not close either bar ordering row or enable the frontend socket flag.
Its private socket/owner tests and retained-bridge gallery are not shared-Quickshell
socket acceptance. Producer `8f30caa` subsequently adds atomic current-state
publications and effect reconciliation, with matched frontend cursor/recovery and
transaction-identity guards. Historical edges remain separate from current state. The subsequent independent
bar socket opt-in and private real-Quickshell probe cover shared reads, publication,
renewal and peer-preserving release, not installed-session or crash/load/performance
acceptance. See the linked recovery record for exact evidence.
Subsequent stages must update this inventory with their actual implemented scope,
not mark all ordering work complete after one stream.
