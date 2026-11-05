# Temporary workspaces implementation plan

Status: implementation authorized, 2026-11-02. Commit at the end of each stage.
Domain logic belongs in Rust and UI in Shelllist QML. No new handwritten
TypeScript, JavaScript, Python or shell implementation. Existing generators and
test runners may be invoked; generated wire data is not a domain implementation.
Compositor Lua expressions are limited to the existing IPC boundary's atomic
identity guards and dispatcher calls, encoded and validated by Rust. Configuration
and documentation remain in their native formats where required.

Implement the temporary workspace proposal from
`/home/laufan/Projects/shelllist-dynamic-workspaces-plan.html`: preserve the five
category destinations, add temporary workspaces, add explicit current/new launch
actions and a saved launch exception, and close a workspace through normal
window-close requests. Preserve the existing Application body and shared panel
interaction model.

Reviewed baseline: Shelllist `f3469e6`, app-daemon `a949e36`, bar-daemon `d520cb8`,
daemon-framework `b0c78d4`. Refresh these revisions and working-tree state before
implementation. Existing project-wide campaign instructions are historical
context, not an instruction to start agents or deploy this feature.

## Product decisions

These decisions resolve the review gaps and guide the implementation. The
multi-monitor fallback and indeterminate recovery rules refine the HTML proposal.

### Launch actions and settings

| Entry point | Behavior | Destination and focus |
| --- | --- | --- |
| Result Enter or Alt+A | Focus an existing app window; otherwise launch | On launch only: saved new-workspace exception, then explicitly assigned category, then captured current workspace. Follow a verified new window only while the originating interaction retains focus intent. |
| Shift+Enter | Request another instance using saved routing | Preserve the existing default-launch shortcut. The new exception applies. Retain the existing plain-launch focus policy. |
| Alt+O, Open here | Request a new window | Captured current workspace; ignore preferences. Follow only while focus intent remains valid. Verify Alt+O has no active command collision before assigning it. |
| Alt+N, Open in new workspace | Request a new window | Fresh temporary workspace; ignore preferences. Follow only while focus intent remains valid. Alt+N intentionally changes from the existing New tile action. |
| Desktop action such as New Window | Run the exact desktop action | Preserve its existing saved-category/current routing and focus behavior. Do not apply the new-workspace exception or silently substitute another desktop action. |
| Per-window focus/close and app Close all | Existing behavior | No changes to targets, acknowledgement or modality. |

Document the desktop-action exception beside the preference's accessible Help:
the switch affects ordinary launches, including Shift+Enter, rather than every
desktop action. Keep desktop-action rows and the Application body unchanged.
Launch-only shortcuts and unmatched running-window groups do not gain new-window
placement controls or a saved exception without verifiable launch ownership.

Store an explicit nullable category and `open_in_new_workspace`, default false.
Distinguish a missing override from explicit Uncategorized. Existing explicit
assignments retain their 1–5 mapping; inferred categories remain display hints
and do not become saved routing. One-shot actions never update preferences.
Category and switch updates must preserve each other's acknowledged value.

Capture compositor session, invoking monitor, current workspace and focus intent
when the action is admitted, before waiting on the app launch lock. The current
frontend `currentWorkspaceId` is captured at panel activation; it cannot alone
satisfy command-time capture. Revalidate the captured destination before effects;
do not replace a missing monitor/workspace with whatever is focused later.
If special/named workspace context cannot be represented and validated by the
new contract, reject that routing explicitly rather than defaulting to Shell.

### Workspace lifetime and monitor fallback

- Keep Shell, Browser, Code, Media and Text as permanent shortcuts for 1–5.
  Temporary positive IDs are globally unique, increase within a compositor
  session, and appear only on their actual monitor.
- Manual + creates and focuses an empty landing pad on the invoking monitor.
  It remains available until an explicit workspace close, including when you
  switch away or its last window leaves. This user-requested lifetime revision
  supersedes the original unused-pad retirement rule (2026-11-03).
- A launch-created temporary workspace retires after its last window leaves and all
  placement leases settle. An unavailable snapshot is unknown, never empty.
  External workspaces retain compositor-owned persistence rules and are not
  silently enrolled as Shelllist-owned landing pads.
- When retirement needs a replacement, accept the compositor's already-selected
  valid local successor, otherwise use the most recent surviving local ordinary
  workspace. Next use an unowned standard destination, preferring 1 when free.
  Never pull a workspace off another monitor or swap its visible contents.
- If every standard destination belongs elsewhere and no local successor exists,
  create one fresh local landing pad. Treat it as the ordinary unused-pad exception
  so cleanup does not immediately retire it again. Test this uncommon fallback.
  Changing a background monitor's active workspace must not take keyboard focus.
- Super+Ctrl+N creates; Shift+Super+Q closes the active ordinary workspace's
  captured windows; Super+Q keeps normal focused-window close. Add
  Super+Ctrl+PageUp/PageDown for previous/next in the monitor's logical strip,
  with wraparound, after checking all included bindings for collisions.
- Super+1 through Super+9 focus the first nine entries in the invoking monitor's
  bar order; Super+0 focuses the tenth. Adding Shift moves the focused window to
  that destination and follows it. Resolve positions in the serialized owner
  using the bar's ordering; keep internal IDs stable and reject missing positions
  without allocation. Later entries use the strip or previous/next commands.
- Left-click only on workspaces and +. Right/middle presses, releases and
  double-clicks must have no effect. Keep + outside the scrolling viewport.

### Close behavior

Capture all mapped window identities on the target workspace, including floating
and hidden windows, rather than the launcher's filtered app list. Revalidate each
identity, compositor session and workspace membership immediately before normal
close. Never close new arrivals or newly created dialogs, move windows out, kill
processes, or repeat a dispatched close automatically. Coalesce duplicate requests
while one close operation is active. New placement leases are rejected during
close; already admitted leases settle before retirement.

App save/cancel prompts and unresponsive windows leave the workspace usable.
After a bounded observation interval, settle as still-open or unknown as
appropriate and restore availability. Later deliberate close commands may capture
a fresh set. Automatic cleanup can finish retirement if the remaining windows
subsequently exit. Standard shortcuts remain after their windows close.

## Ownership and protocol contracts

bar-daemon owns allocation, monitor membership, session metadata, placement
leases, workspace close and retirement. app-daemon owns app settings, launch
execution, provenance and deciding which new window is eligible for placement.
Shelllist renders acknowledged state and submits commands; it allocates no IDs.

Use the existing authenticated session transport between app and bar. Confirm its
reconnect and service ownership behavior in the first checkpoint. Do not create
a Cargo dependency cycle or a second mutable registry in Shelllist. Keep domain
policy in its daemon; extract only reusable transport/identity primitives into
daemon-framework when needed.

Freeze typed request/result contracts before implementing consumers. Names below
are proposed responsibilities, not claims that these endpoints already exist:

| Contract | Required fields and semantics |
| --- | --- |
| Capabilities | Protocol version and support for create, close, launch targets, preference and placement leases. Unsupported controls cannot submit effects. |
| Workspace create/reserve | Compositor session, monitor identity, durable request key, purpose (landing pad or launch), origin cue, app operation correlation. Return the same reservation for a duplicate matching request; reject key reuse with different parameters. |
| Placement lease and apply | Session, reservation/workspace generation, operation identity, verified candidate window identity and expected membership. Commit/release is idempotent. A stale or revoked lease cannot dispatch a move. |
| Workspace close | Session, workspace identity/generation and request key. Persist captured targets and per-target dispatch state; expose observed outcomes separately from request admission. |
| Operation lookup | Read by durable request key as well as operation ID, including after a lost admission reply. Lookup never replays an effect. Apply authenticated ownership to recovery reads. |
| Workspace publication | Existing publication lineage plus workspace session/generation, monitor, ownership kind, occupied history, stable origin cue and operation state. Full replacement reads repair missed events. |
| App execute/settings | Explicit launch intent, captured context, preference revision and nullable category/boolean. Preserve separate launch, placement and focus results. |

Route lease-governed placement dispatch through bar's lifecycle owner after app
proves the candidate. This makes lease revocation and placement admission share
one serializer; a separate check in app followed by an unguarded compositor move
would leave a race with retirement. Bar validates session and live window identity
again. App continues to own provenance and placement outcome interpretation.
Include placements into standard destinations in close/lease coordination.

Keep record counts, admission, journal retention, numeric bounds and payload
sizes bounded. Persist the high watermark before exposing an allocation; fail
without wrapping or reusing IDs at the supported limit. A workspace ID alone is
not identity when an external compositor client can recreate it.

## Durable recovery

The current app operation registry is memory-only. Introduce a private,
session-scoped launch journal before enabling temporary launch routing. Bar's
registry and app's journal live under their own `$XDG_RUNTIME_DIR` directories,
keyed by compositor identity; app preferences remain durable configuration.

Persist request identity, immutable intent, destination/reservation, launch
baseline/provenance evidence and dispatch state before the corresponding effect.
Record checked handoff, placement and release receipts as they become known.
Use atomic durable writes and reject new effects when their required journal
cannot be written. Bound terminal history without expiring unresolved records
or permitting an expired request key to become a fresh command.

Recovery follows these rules:

1. Fence the old app/bar writer generation and reconcile existing compositor
   state before admitting mutations. Session changes invalidate old leases,
   captured contexts and requests, while leaving preferences intact.
2. Read by the original request identity after lost replies. Never automatically
   rerun an app launch or a close whose dispatch may have happened.
3. A crash between process handoff and receipt persistence is indeterminate.
   A journal cannot make an external launch exactly once. Recover using available
   process/window evidence; keep the outcome unknown if ownership is unprovable.
4. Resolve placement separately from launch success. An unused reservation can
   be released with an indeterminate launch result only after all old placement
   writers are fenced, previously issued compositor requests are reconciled,
   and no live window or user adoption occupies it. If that cannot be proved,
   retain the reservation and reconcile again; a timeout is insufficient.
5. A terminal indeterminate launch must never be displayed as success or failure
   with a replay suggestion. After placement is closed, a late app window is left
   where the compositor maps it; do not revive a placement task. If it occupies
   an old ID, reconcile it as a live workspace without reusing the allocation.

This replaces the proposal's dependence on always recovering a definite terminal
launch outcome. Validate every boundary with real daemon termination and restart
against private compositor/process fixtures, not only in-process mocks.

## Implementation checkpoints

Work through these checkpoints in order. Each includes the owning code, negative
cases, documentation and passing checks before the next dependent checkpoint.

### 1 Verify compositor operations and freeze the contract

Inspect installed Hyprland Lua/IPC behavior and Nix source bindings. Prove normal
per-window close, monitor-targeted focus without swaps, empty workspace behavior,
class-rule override placement and the check/dispatch race boundary in a private
compositor session. Determine whether compositor-side validation is required to
prevent closing a window that moves after a daemon-side check; do not ship a
stronger guarantee than the available primitive provides.

Freeze session/generation identity, peer transport, capability negotiation,
journal formats, lease lifecycle and the action table above. Add an executable
fixture and tracked contract alongside this plan. Record spike evidence in
`tests/temporary-workspaces-spike.md`. Unsupported monitor targeting or safe
close semantics block those features rather than silently weakening them.

### 2 Implement the workspace owner in bar-daemon

Extend `src/hyprland.rs`, `src/protocol/session_controls.rs`, protocol exports and
daemon routing, with a dedicated workspace lifecycle module. Add durable
allocation, request lookup, reservations, guarded placement, close observation,
cleanup and restart reconciliation. Keep slow compositor I/O outside global
unrelated-domain locks; serialize lifecycle state transitions explicitly.

Tests must cover simultaneous creates, external ID collision, request duplication,
corrupt/unwritable journal, process restart, external persistence, moved/reused
window identities, new dialogs, pending-placement/close races, monitor removal
and every fallback branch. Read-only recovery must perform no launch or close.

Exit: create/lease/close APIs and full workspace publications are usable through
the production transport with private fixtures, without frontend changes.

### 3 Implement app settings and recoverable launch routing

Change `src/settings.rs`, `src/service/query.rs`,
`src/service/operations.rs`, `src/service/action.rs`, request validation and
generated protocol fixtures. Settings v2 preserves saved assignments, represents
explicit Uncategorized, and defaults the exception off. Preserve the v1 file
for downgrade and write v2 separately; define subsequent v1/v2 preference divergence
explicitly rather than letting an older daemon overwrite v2 state.

Add the launch journal and bar client. Under the existing per-app launch lock,
recheck live windows before resolving an Activate launch or reserving anything.
Resolve each entry point from the action table. Record launch ownership before
placing only a verified new window, preserving singleton/D-Bus/UWSM behavior.
Capture focus intent independently of automatic launcher dismissal, and invalidate
follow when the user navigates elsewhere.

Tests include nullable/missing settings, independent field updates, every routing
precedence, running Activate with the exception on, Shift+Enter, unchanged desktop
actions, launch-only targets, slow/ambiguous/singleton handoffs, lost replies and
crashes before/after handoff, placement and lease release.

Exit: daemon-to-daemon routing and recovery pass without duplicate launches,
moving old windows, or claiming placement solely from dispatch acknowledgement.

### 4 Extend the bar and launcher in Shelllist

Publish monitor-local ordered strip models from Rust, replacing the workspace
strip's TypeScript policy dependency. Update `bar/WorkspaceStrip.qml`,
`bar/WorkspaceButton.qml`, controller/backend adapters and generated contracts.
Add the conditional divider, fixed +, stable icon/number cue and geometry-based
active reveal. Keep acknowledged selection, occupancy and urgency independent.

Update `launcher/ApplicationProvider.qml`, `ApplicationController.qml`,
`ApplicationContent.qml`, backend/operation adapters and
`ApplicationSettingsPage.qml`. Preserve Shift+Enter's explicit default-launch
route; remove any accidental alias to the new Alt+N action. Preserve Application
body rows, pills, App data, desktop actions and bottom tabs. Add only the header
actions and the shared exception switch beside the existing category editor.

Use ProviderChooserSurface, DetailsHeader/SurfaceActionRow, FormField/FieldRow,
DropDownList and the shared switch. Enter/Tab save, Escape discards, arrows never
write, and action buttons never become field Tab stops. Preserve category option
click-save and switch activation behavior. Submitted saves remain scoped to the
originating app and return to acknowledged values on failure. If feedback is
shown, use FeedbackSource; no growing rows or mandatory new status presentation.

Add actual Qt key/pointer tests for both new controls and existing action paths.
Cover modality, failed settings, stale selection, reconnect without replay,
right/middle input, scrolling reveal, narrow/high-DPI geometry and retained
Application body composition. Update tracked interaction contracts and fixtures.

Exit: all controls operate against the new APIs and fail closed on older peers;
existing actions remain usable when the new capability is unavailable.

### 5 Integrate packaging and shortcuts

Update generated protocol outputs, contract fixtures, source filters
and matching dependency pins as a coordinated repository family. Use the existing
local-build tooling and build-input policy; avoid unrelated dependency upgrades.

Edit `/etc/nixos/config/hypr/hyprland.lua` and its shortcut tests, not generated
user configuration symlinks. Route + and creation/close/navigation shortcuts
through the same owner and request semantics. Keep standard 1–5 focus/move
bindings and class rules; do not globally toggle class rules during launches.
Disable repeat for destructive workspace close. Preserve Super+Q.

Exit: the packaged family builds and passes import, generated-source, protocol,
binding and mixed-version checks. Do not activate a host configuration as part
of a build check.

### 6 Qualify the complete feature and prepare rollout

Run the private process crash matrix with both daemons and the actual Shelllist
transport. Exercise lost final events, dropped admission replies, stale sessions,
bounded admission and compatibility with each older peer independently. Validate
that unknown outcomes retain honest state without repeated effects.

Then perform controlled live acceptance with terminal, browser, editor, singleton
and D-Bus launches; app save/cancel; two monitors; unplug/replug; gesture navigation;
standard/temporary workspaces; and late focus changes. Record source and package
revisions, commands, results and remaining limits in
`tests/temporary-workspaces-qualification.md`.

Deploy the matched daemon/frontend family only after implementation and private
qualification. Rollback disables new entry points, retains live windows and
ordinary workspace access, preserves v2 settings and recovery metadata, and
settles or fences placement writers before replacing services. Rolling back is
not a command to close temporary workspaces or replay pending launches.

## Validation and completion

Use the pinned development environment; `python3` is not available in the plain
shell used for planning. Follow the repositories' existing local-build wrappers
for package checks and select the affected checks from their current manifests.

- Changed Rust crates: formatting, locked tests, Clippy and private transport/
  process fixtures. Test shared-framework consumers if primitives change.
- Shelllist: `tests/run-qml-tests.sh`, `tests/run-qmllint.sh`, TypeScript freshness,
  generated protocol and app/bar fixture parity, plus packaged import checks.
- UI review: `python3 tests/review-panel-ui.py --base <implementation-base>`;
  document an owner and reason for any new numeric geometry overrides.
- Nix: coordinated local-build checks and packages, build-input consistency,
  source filters and shortcut tests using the final revision family.
- Keep runtime captures/logs in ignored output directories and concise evidence
  in `tests/`. Put executable contracts in `contracts/`; do not re-add `docs/`.

Implementation is complete when all six checkpoints have recorded outcomes,
every reviewed recovery/monitor/shortcut gap has a passing regression, and the
packaged feature preserves shared interactions and existing application behavior.
Mocked/offscreen results do not count as live compositor acceptance. No runtime
test or deployment is claimed by this planning document. Stage evidence records
actual results separately.
