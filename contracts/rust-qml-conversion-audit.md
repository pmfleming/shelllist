# Rust/QML conversion audit and implementation tickets

Status: **coordinator-reviewed inventory/tickets; no conversion or rollout approval**.
The integration review accepts this responsibility inventory as a bounded planning
checkpoint, not approval to implement every ticket. Source statements below remain
anchored to the frozen heads; later scoped recovery implementations must be checked
against the current stream matrix before assigning work.
Audited 2026-10-26 against the frozen sources below. Paths in code spans are
relative to the sibling worktree family unless explicitly stated otherwise.
This document resolves the inventory, not the broader migration's exit gates.

## Scope, identities and evidence

| Repository | Audited source HEAD |
| --- | --- |
| shelllist | `d7a3a5e530a0fd350075f1ca85e3f83539dc6089` |
| bt-daemon | `3e0ecb4f81aeada42cd3623dedb7fa4d3c46995f` |
| nm-daemon | `0396f009eca7f28219e8da23ba69e9eac720a7f9` |
| bar-daemon | `cca60419d933c995d61d297be19847496c05de68` |
| app-daemon | `bb013f1659e2e4b2689fc19d4c331affd5624662` |
| daemon-framework | `563e7f95e0b976e1e2eb483bc4e983623f0e8fc5` |
| update-daemon | `7c3432f22ea82ebcd941f6ce8bcd562e2724d130` — read-only Rust status crate only |

Inspected the named helpers, their consumers, producer models/coordinators,
serialization/projection paths and relevant retained tests. **No native binary was
built or executed for this audit.** Existing test sources and historical results
are evidence of intended coverage, not fresh passing acceptance. Checks for this
change are documentation/path/whitespace checks only; native acceptance below is
required work for each implementation ticket. Potential behavior defects below
are source-level witnesses, not executed reproductions or permission to bypass
the assigned owner.

### Decisions at a glance

- Retain Core/Model, editing/navigation/request-window transactions, asset tables
  and most ApplicationPresentation helpers in QML; no blanket JavaScript port.
- Move BT scan recommendations/list facts, remaining NM form policy and selected
  update/media/status semantic calculations behind explicit native contracts.
- Replace hand-maintained wire predicates with generated enforcement, not with
  unconditional trust in producer output.
- BT/NM lifecycle recovery is already a transport-rollout prerequisite; ownership
  conversions are separate project-completion work.
- Media cadence/interpolation, cross-language schema parity and network/calendar
  scope need evidence/owner decisions before their conversion is selected.

Prerequisites remain [stream matrix](unix-jsonl-stream-matrix.md),
[recovery contract](unix-jsonl-stream-recovery.md) and
[request lifecycle](request-lifecycle.md). Read `shelllist/AGENTS.md` first.
Local ignored keyboard/UI references were read; missing domain references were
read with its `git show 71e1b3e:docs/<filename>` fallback (updates, media,
application-actions, application-details and Wi-Fi operation/credential records).
These historical references are subordinate to AGENTS.md and current code;
in particular, mandatory visible feedback and obsolete keyring behavior must not
be reintroduced. Do not track the ignored docs tree.

### Classification

- **R — Rust domain policy/projection:** producer validates or computes semantics;
  QML consumes explicit facts. R can mean already correctly native, not new work.
- **Q — justified QML/UI responsibility:** rendering/assets, geometry, navigation,
  request/view identity, local drafts and editing/publication transactions.
- **D — duplicate/fallback policy to remove:** replace only after a matching native
  contract and negative-path consumer coverage exist. Generated JS validation is
  an enforcement boundary, not a second hand-maintained policy implementation.
- **U — uncertain:** named evidence/decision is required before implementation.

A function may straddle categories. Generic malformed-data checks are not domain
fallbacks. Producer truth does not eliminate consumer ownership, shape, freshness
or captured-target checks. Neither request admission nor a state read proves that
an uncertain effect succeeded.

## Responsibility inventory

### BluetoothFlow

Source: `shelllist/typescript/bluetooth/BluetoothFlow.ts`; generated output:
`shelllist/bluetooth/BluetoothFlow.js`. Relevant consumers are
`shelllist/bluetooth/BluetoothController.qml`,
`shelllist/bluetooth/BluetoothOperationController.qml`,
`shelllist/bluetooth/BluetoothProvider.qml` and
`shelllist/bluetooth/BluetoothBackend.qml`.

| Responsibility / symbols | Class and disposition |
| --- | --- |
| `emptyRadio` | Q: explicitly unavailable initial UI state, not a successful observation. |
| `radioForSnapshot` adapter-derived fallback | D: native `Snapshot.radio` includes rfkill and operational state; adapters alone cannot reconstruct it. Normal backend `BtApi.validSnapshot` already requires radio/management, so this is redundant fallback cleanup, not evidence the production cursor accepts missing radio. |
| `activeRequests`, `requestState`, `isActiveOperation` | Q: project validated lifecycle DTOs into local pending/UI state. U: aggregate request recovery is not an ordered owner-private status contract; CQ-01 precedes any stronger assumptions. |
| `pairingQueue`, `scanTransition` | Q for local keyed queue/selected scan; R for authoritative membership/expiry/terminal order. Do not move private input drafts into Rust. Producer pairing display replacement already deduplicates device/kind; UI dedup is not recovery authority. |
| `shouldRescanAfterOperation` | R: pair + failed + `device-unavailable` is domain recovery policy; Q: current UI scope, powered/available gating, duplicate-request guard. Move the domain predicate, not UI activation, under CQ-02 after CQ-01. |
| `shouldStartScan` | Q for an explicit active All-devices browsing intent; R for scan lease/backend eligibility. Never invoke it as generic gap/status recovery. Current `applySnapshot` can start scanning; distinguish this intent from read reconciliation before conversion. |
| `devicesForView` | R: interpretation of persisted show-blocked/show-recent settings, paired/present membership. Q: selected My/All view. Native scope membership should replace the predicate (CQ-03). |
| `deviceScore` | R: connected/paired/present/signal ranking weights. Search already runs in Rust, but this score is still computed in TS; move score production, not the existing search engine. |
| `deviceBaseName`, `adapterDisplayName`, `deviceDisplayName` | R for collection-wide duplicate-name resolution; Q for final localized fallback copy and separator. Native collection projection can supply disambiguation identity without hardcoding visual assets (CQ-03). |
| `adapterLabel`, `radioStatus`, `pairingStatus`, `completedCallStatus`, `scanCompletionStatus`, `operationCompletionStatus`, `activeOperationStatus`, `audioProfileStatus`, `audioSwitchStatus`, `deviceState` | Q: label/message selection from authoritative flags/outcomes. Keep unknown/partial persistence messages; do not infer hardware success from a generic completed call or translate labels into permission checks. |
| `retainedAdapterKey` | Q: selection retention, not a persisted preferred-adapter policy write. |
| `directActionRequest`, `toggleActionRequest`, `multipointActionRequest`, `deviceActionRequest` | Q: explicit command-to-wire mapping and toggled desired value; native backend revalidates capability and policy. D: `pair && !device.policy` injects global `trust_after_pair`; native effective policy already exists. Missing policy must not choose a weaker/default policy. |
| `audioPresentation` | Q: retain profile labels/options while reconnecting. Must remain device-keyed; never restore live routes, capability, acknowledged profile or apply authority from presentation cache. |
| `hasRelativeSignal`, `signalLevel`, `hasSignal`, `signalQuality`, `signalValue`, `signalLabel` | R already: bt-daemon owns RSSI unit interpretation, strength and bar thresholds. Q: defensive finite/clamped rendering, relative-dB/cached labels and asset quality names. Do not add another RSSI-to-percent algorithm. |

Producer anchors: `bt-daemon/src/model.rs` (mandatory radio, effective policy,
capabilities, signal provenance), `bt-daemon/src/management.rs` (defaults and
per-device overrides), `bt-daemon/src/bluez/snapshot.rs` and
`bt-daemon/src/bluez/snapshot/assembly.rs` (capabilities/signal),
`bt-daemon/src/bluez.rs::pair_with_policy` (native trust default),
`bt-daemon/src/daemon/scan.rs` (owner scan leases and shared-adapter cleanup),
`bt-daemon/src/daemon/operation.rs` (admission, per-device exclusion, recent outcomes),
`bt-daemon/src/pairing.rs` (actual pending/display replacement, validation/expiry).
`bt-daemon/src/daemon/obex.rs` exposes capabilities, not retained transfer outcomes;
its incoming agent is explicitly opt-in because Shelllist has no transfer UI.
`bluetooth.requests.snapshot` in `bt-daemon/src/daemon.rs` is an aggregate;
`retain_terminal` explicitly records recent operations without owner privacy.
Lifecycle forwarding in `bt-daemon/src/daemon/subscription.rs` is not covered by
the radio/audio publication clocks. Do not mistake either for CQ-01 completion.

### WifiPromptPolicy

Source: `shelllist/typescript/wifi/WifiPromptPolicy.ts`; generated output:
`shelllist/wifi/WifiPromptPolicy.js`; consumer:
`shelllist/wifi/WifiPromptController.qml` and its credential dialog.

| Responsibility / symbols | Class and disposition |
| --- | --- |
| `field`, `initialValues`, `enterpriseLabel`, `secretLabel`, label tables, `forgetCopy` | Q: local initial drafts, translation/display labels and confirmation copy. Unknown field keys can be readable without acquiring an invented authority/type. |
| `hiddenFields`, `hiddenChoice` | R already: hidden fields, defaults, security mappings, conditional required fields come from native `HiddenPrompt`; Q: render/choose native descriptors. Missing descriptor already prevents opening the hidden form. |
| `enterpriseDefault`, `enterpriseFields` | D: frontend fallback `peap`, required EAP/identity and optional password duplicate native `NetworkConnectPrompt`/`EnterpriseAuth`. R: native complete field/default descriptor; Q: initialize local values from it. |
| `enterpriseSecret` | D: substring `password`/PIN masking classification is a frontend schema guess. Producer must advertise field secrecy/type. |
| `daemonSecretSpec` | D: fallback to primary key or `password`, all-fields-required and `pin` unmasked are policy choices, not just labels. Native emits `secret_keys`, but not the complete per-field rendering descriptor used by hidden forms. CQ-05 must close this gap, not claim it is already migrated. |
| `enterpriseObject`, `connectionRequest` | R: allowlisted enterprise fields, omission semantics, EAP list normalization and connect-target validation. Q: capture submitted values/target and package a save. Prefer one native raw-form normalization boundary over a second UI enterprise policy. |
| `validationError` | Q: cheap required-field feedback from a validated native descriptor. R: authoritative completeness/security/certificate validation before execution. Do not remove local save feedback or send validation on every keystroke. |
| Remember/save requirements, acknowledgement, expiry, secret clearing in controller | R already: NM authorization, persistent/temporary/mixed ownership and delivery/storage confirmation. Q: show native choices, keep current private drafts and submitting lock, correlate expiry/receipt, clear secrets. Conservative old-agent save-required handling cannot simply be deleted before required metadata/mismatch handling is defined. |

Producer anchors: `nm-daemon/src/model/prompts.rs` (hidden descriptors),
`nm-daemon/src/model.rs::enterprise_prompt` and `NetworkConnectPrompt`
(required/optional fields and defaults), `nm-daemon/src/nm/wifi_settings.rs`
(EAP defaults, identity, certificate and storage validation),
`nm-daemon/src/network_credentials.rs` (supported schemas and exact secret keys),
`nm-daemon/src/daemon_secret.rs::emit_secret_requested` and
`PendingSecretRequest::prepare` (authorized key list, remaining lifetime,
save support/requirement), `nm-daemon/src/daemon_secret/storage.rs::Policy`
(mixed/system/agent/NOT_SAVED policy). `provide`/`PendingRegistry::remove_for_owner`
already restrict responses to the captured observer owners and live request;
recovery must preserve that existing authority, not replace it. Acceptance,
delivery, activation and durable
storage are different outcomes. No migration to a new keyring provider is proposed.

### UpdateValidation and UpdateController

| Responsibility | Class and disposition |
| --- | --- |
| `shelllist/bar/UpdateValidation.js` primitive `text/flag/nullable/optional/integer/list/field/version/runId`, `optionalText/optionalFlag/observedTime/historyTime/count` | R for schema source; D for separately maintained static wire predicates once producer-generated equivalents exist. Q: still enforce wire validity at the consumer boundary; do not just trust JSON because Rust emitted it. |
| `system/baseline/git/release/application/applications/freshness/tool/timer/overviewIssue/overview/incident/component/historyIssue/entry/historyPage` | R for schema and semantic invariants; Q for publication-time malformed-input rejection. Relational constraints (e.g. recovery time after failure, total >= page length) are not automatically expressible by deriving serde/JsonSchema. CQ-06 must inventory the exact supported subset before removing predicates. |
| `UpdateController.qml` owned overview/history/log reads, coalesced refresh, run/log identity, request retirement, staged window, cursor restart, deadline and atomic publication | Q: UI invocation/query transaction. Native history already handles catalog search/revision cursors. Keep independent read ownership and one bounded read-only restart. |
| Filter enums and `openRun` regex | Q for command allowlist/early input rejection; D only for hand-maintained copies of published native enums/run-ID format. Generated constraints can replace copies; producer still validates requests. |
| Now pinned row, keyed selection/viewport, tabs/settings, expanded groups, command routing, log cache/version/retry, local timers, copy intent | Q. UI copy remains through the existing guarded publisher; tests must record, never touch real clipboard. Failed log reads stay cached until explicit retry. |
| Eligibility to Apply/Approve/Retry updates | **Not present.** The controller only reviews/copies/reads. Do not invent an update execution migration ticket from its name. Preserve its read-only boundary. |

Producer anchors: `bar-daemon/src/updates/overview.rs` normalizes bounded worker
reports, nullable evidence and stale application releases;
`bar-daemon/src/updates/history.rs` validates requests, reads private bounded
records/logs, reconciles abandoned jobs, queries/filters and fences cursors;
`bar-daemon/src/updates/catalog.rs` computes later recovery without rewriting
historical failures; `bar-daemon/src/updates.rs` validates native readiness.
`update-daemon/crates/shelllist-update-status/src/history.rs::RunRecord` owns
outcome/title and input record validation; read it, do not fork that policy.
These are Rust read-side contracts; ecosystem-maintenance/update-daemon Python
work, upstream checking/installing and deployment are excluded.

Current `bar-daemon/src/protocol.rs` advertises the update read methods as examples,
not complete result schemas. Media/update streams mostly have only the common
available/publication schema. Existing typed audio/brightness/profile contracts
in `bar-daemon/src/protocol/control_wire.rs` demonstrate the mechanism but do not
validate update pages. `shelllist/qml/Shelllist/Io/DaemonBackend.qml` exposes
request/event validators; its `responseError` checks the envelope, not arbitrary
method-specific generated result schemas. CQ-06 must wire actual result validation,
not merely generate a currently unused schema.

### Core/Model schema helpers

File: `shelllist/qml/Shelllist/Core/Model.js`.

| Responsibility / symbols | Class and disposition |
| --- | --- |
| `schemaVersion`, ID/role/kind/close-policy/group/tone enums; `provider`, `action`, `actionList`, `result`, `resultList` | Q: **frontend chooser construction schema**, not a producer domain/wire schema. Defaults describe UI construction; not an alternative daemon capability policy. Keep uniqueness, single visible primary and referenced-primary validation. |
| `fail`, `objectOrEmpty`, `stringValue`, `nonEmptyString`, `identifier`, `finiteNumber`, `booleanValue`, `enumValue`, `stringList`, `ensureUnique` | Q: local descriptor normalization/defensive checks. U: permissive coercion may warrant a separate strict/raw-vs-normalized boundary review; no evidence here justifies inventing a shared Rust chooser ABI. |
| `keepOpenAction`, `settingToggle`, `visibleActions` | Q: action composition/presentation. Disabled actions keep slots/order; labels/commands do not become editable stops. Capability enforcement stays provider/native. |
| `resultKey`, `indexByKey`, `actionById` | Q: stable frontend keys and selection/action lookup. |
| `queryRequest`, `executionRequest` | Q: captured UI request/selection context and enabled/visible guard. R already: search ranking and daemon execution validation. A local execution ID is not authorization or a native operation ID. |

Consumers: `shelllist/qml/Shelllist/Core/Provider.qml`,
`shelllist/qml/Shelllist/Core/ProviderRegistry.qml`,
`shelllist/qml/Shelllist/Core/ResultStore.qml`. The store deliberately separates
normalized/raw construction and retains accepted rank windows.
`shelllist/rust/shelllist-search/src/lib.rs` consumes only ranking items, not this
entire UI schema. App native `ApplicationSummary`/`ApplicationAction` and BT native
capabilities are distinct types. **No duplicate producer schema was identified
in Model.js.** CQ-14 closes this candidate as retain, with a bounded uncertainty
review rather than a speculative Rust port.

### BarIndicators, BarMediaPresentation and BarStatusPresentation

TS sources are under `shelllist/typescript/bar/`; corresponding generated JS is
under `shelllist/bar/`. Do not edit generated copies independently.

| Helper / responsibility | Class and disposition |
| --- | --- |
| Indicators `audioIcon`, `powerProfileIcon` | Q: glyph selection, including 34/67 glyph cutoffs; not a second volume/power policy. Unknown-profile lightning glyph is a visual fallback, not permission to select Performance. |
| Indicators `percent` | Q when clamping paint geometry. D/U where numeric-or-zero coercion labels missing telemetry as zero (`BarOsdPresentation`, network tooltip). Native range/availability and unknown text need explicit projection; don't move pixel clamps to Rust (CQ-10). |
| Media `playerFor` | Q: resolve daemon's `active_player`, never choose a different player by frontend scoring. R already: native active selection, pinning and control-mode persistence. |
| Media `trackControls`, `transportAction`, `canPlayPause` | R: automatic track-vs-seek semantics and allowed transport. Q: map native operation/capability to icons/labels and explicit click. Existing producer owns mode/content/capabilities but not this resolved action projection (CQ-08). |
| Media `serviceFor`, `contentKind` | R already: native source URL recognition and content provenance. D: source-less Pocket Casts/Audible content-kind inference. Exact desktop/identity tables are Q if used only for logos/name aliases; R if used for semantic classification or search evidence. Preserve the distinction, not a blanket delete. |
| Media `identityLabel`, browser identity table/ID regex, `heading`, `subtitle`, `distinctLabels` | Q for composition/plain-text dedup; R for discovering service/origin facts. Producer browser identity already exists; CQ-08 should publish resolved identity facts, not parse URLs/titles in QML. |
| Media `contentIcon`, `stateIcon`, `playPauseActionIcon`, `actionGroup` | Q: asset/command grouping lookups from native state. |
| Media `durationText`, `timeline` | R: valid/unknown duration/position, units, rate, timing freshness and extrapolation bound. Q: passive progress pixels/timer/animation. U: producer sampling contract is not established; CQ-09 is a decision/probe prerequisite, not authorization to relocate every local timer. |
| Status `batteryKnown`, `batteryFraction` | Q: known guard and bounded fill geometry. R: underlying validity/availability. Keep unknown distinct from zero/full. |
| Status `batteryStateMark`, `batteryStateLabel`, `batteryTone` | Q: marks/tone from native state/flags. D: inferring fully charged from plugged + clamped 100% when native state says otherwise. Native warning/critical thresholds already exist. |
| Status `batteryTooltip` | D/R: independent duration/unit rounding and numeric-or-zero `power_watts` ignores `power_available`; native `display.power` already preserves zero versus missing. Reuse/extend native display facts (CQ-10), keep punctuation/assets local. |
| Status `orderedPowerProfiles`, `nextPowerProfile` | Q if merely presenting/navigating choices; R when selecting the next profile for an immediate effect. Current bar invokes a set from this inferred order, including unknown extras rejected by native set (CQ-13). |
| Status `networkKind`, `networkIcon`, `networkTooltip` | Q for glyphs/tooltip composition; D/U for interpreting active + missing AP as Ethernet. The supplied state is Wi-Fi-specific, not an Ethernet inventory contract (CQ-12). |
| Status `bluetoothTooltip` | Q: connected count label from validated devices, not pairing eligibility. No new native BT subscription just to count a rendered collection. |
| Status `utcOffset`, `clockParts`, `clockModule` | R: time/offset/calendar projection; D: recomputation and local-host fallback versus existing native clock projections. Q: one clock action, density-dependent date/tooltip formatting assets (CQ-11). |
| Status `notificationsModule` | Q: icon/tone/count/sharing prompt composition from native DND/sharing/urgency. R already: urgency normalization, sharing detection and notification suppression. Numeric/critical alias compatibility is not a new delivery policy. |
| Status `statusModule`, `statusModules`, `layoutDensity`, `statusModuleEqual`, `nextMinuteDelay` | Q: composition, equality and width geometry; minute timer scheduling is Q only if used to render a defined native-clock contract, not infer missing clocks. Remove that clock timer if CQ-11 adopts native minute publications. |

Producer anchors: `bar-daemon/src/media.rs::MediaSelection/read_player`,
`bar-daemon/src/media/source.rs`, `bar-daemon/src/media/browser_identity.rs`,
`bar-daemon/src/model.rs`, `bar-daemon/src/presentation.rs`,
`bar-daemon/src/battery/mod.rs` (derived charge state/thresholds),
`bar-daemon/src/power.rs::set_profile`, `bar-daemon/src/timezone.rs`,
`bar-daemon/src/activity/presentation.rs` (native clock/date/unit projections),
`bar-daemon/src/activity/notifications/server.rs` (normalized urgency).
Network status comes through `shelllist/bar/BarController.qml::networkStatus`
from `WifiController.activeStatus`, whose producer type is
`nm-daemon/src/model.rs::WifiStatus`, not a bar-owned network model.

### UpdatePresentation and ApplicationPresentation

| Helper / symbols | Class and disposition |
| --- | --- |
| `shelllist/bar/UpdatePresentation.js`: `label`, `outcomeIcon`, `exitLabel`, `shortVersion`, `logSource`, `logTone` | Q: localization/assets, readable version elision and plain-text log emphasis. Full paths/diagnostics remain in copy payloads. Color matching `error:` must never determine domain failure. |
| `changeSummary`, `componentGroups`, `componentCount`, `recoverySummary`, `toolsSummary`, `gitSummary`, `deferredCandidate`, `laneStatus`, `laneOverview`, `systemSummary`, `isRunning` | R for semantic counts/membership/status precedence and current-vs-historical evidence. Q for wording and groups' visual arrangement. Several already consume native outcome/recovery/comparison correctly; extend those facts rather than reconstructing outcome from job phase/version strings (CQ-07). |
| `validTime`, `timeLabel`, `dateGroup`, `durationLabel`, `absoluteTime`, `ageLabel` | Q for local-calendar human formatting; R for validity/unknown-vs-running duration/freshness semantics. U: frontend/backend calendar-zone agreement and dynamic-duration clock contract need explicit tests, not automatic server localization. |
| `componentSummary`, `runSummary`, `issueLabel`, `toolFreshness`, `toolRows`, `rowSubtitle` | Q for readable/localized display/copy composition; R/D only for embedded semantic decisions identified above. Freshness comparison is native evidence; no local version arithmetic. |
| Related `shelllist/bar/UpdateHistory.js::routine` and `routineEnd` | R: conservative fold eligibility (failure/hold/incident/manual exclusions); Q: loaded-only groups, local-day grouping, expansion/selected-anchor retention. `UpdateHistoryWindow.js` remains Q unpublished-window/continuation transaction. |
| `shelllist/launcher/ApplicationPresentation.js`: `runningWindowIcon`, `categoryFilterOptions`, `categoryFilterOption`, `nextCategoryFilterOption`, `pageStatus` | Q: icon, local category filter navigation and loaded-page status wording. Native catalog owns categories, match/runtime scores and `has_more`/compositor evidence. Nothing here computes app search or placement. |
| Application `isCloseAction` | Q mapping, but used in a safety-sensitive dismissal decision, not just paint. D: independent `close-window-` classifier alongside `ApplicationLifecycle.expectedOperationAction`; canonical submitted/native action already exists. CQ-15 removes duplicate classification, not the no-handoff-on-Close guard. |

Application producer anchors: `app-daemon/src/model.rs::ApplicationSummary`,
`app-daemon/src/service/query.rs` (category filtering and native ranking),
`app-daemon/src/settings.rs` (validated category/workspace policy),
`app-daemon/src/service/action.rs::ApplicationAction/operation_result/close_application`,
`app-daemon/src/service/identity.rs`, `app-daemon/src/launch.rs`.
Close observation is producer-owned; missing close evidence never means success.
Frontend `shelllist/launcher/ApplicationOperations.qml` owns captured invocation,
pending target, owned status polling and whether the current chooser may dismiss.
That local UI transaction must not migrate into the daemon.

## Ticket contract common to all changes

Every ticket below is a **separate reviewable producer/frontend change sequence**,
not permission for this audit worker to edit those repositories. Shared files such
as bar `model.rs`, `protocol.rs`, generated fixtures and frontend BarController
need serialized owner handoffs; the tickets are not conflict-free parallel edits.
Required new DTO modules below are explicitly marked proposed. No lockfile changes.

Retain in every ticket: bridge default; supported D-Bus/legacy callers; validation
on both transports; matching-schema failure closed (never local fallback/replay);
owner/generation/request fencing; accepted-work admission until actual completion;
owner cleanup as cancellation, not rollback. No recovery path starts a scan,
connection, launch, paste, publication, update, notification or another uncertain
effect. Only a separately captured explicit UI intent may start new work.

QML keeps field-local drafts, source bindings, geometry, navigation and save/discard:
Enter saves, Tab/Shift+Tab save and continue, Escape discards; native arrows stay
inside editors. Unsubmitted changes/blur/view closure never write, except explicitly authorized
continuous-preview transactions with their existing rollback/acknowledgement guards.
Labels, Help, telemetry and commands add no editable stops; commands retain modal/capability
checks. Submitted failures keep explicit retry/unknown state; discard never claims
backend rollback. Secret drafts are private, non-restorable and cleared on their
actual expiry/close boundaries. Clipboard confirmation, leases and hidden-session
handshakes are untouched. Updates remain read-only.

### CQ-01 — BT lifecycle recovery prerequisite

**Owner/files:** BT owner: `bt-daemon/src/daemon/operation.rs`,
`bt-daemon/src/daemon/scan.rs`, `bt-daemon/src/pairing.rs`,
`bt-daemon/src/daemon/obex.rs`, `bt-daemon/src/daemon/subscription.rs`,
`bt-daemon/src/daemon.rs`, `bt-daemon/src/protocol.rs` and their private tests.
Frontend BT owner: `shelllist/bluetooth/BluetoothBackend.qml`,
`shelllist/bluetooth/BluetoothOperationController.qml`,
`shelllist/bluetooth/BluetoothController.qml` and generated BT contracts/fixtures.

**Contract/work:** finish the existing stream-matrix lifecycle rows, not the
completed radio/audio cursors. Define atomic per-request status/event ordering,
producer lifetime, retained terminal bounds and missing/expired outcome behavior.
Provide authorized read-only recovery for operations/scans/pairing/OBEX as needed;
aggregate active/recent lists do not prove owner-private outcomes. Specify prompt
observation versus response authority, remaining expiry, closed/dismissed IDs,
owner filtering and quiet terminal loss. Do not silently make pairing private
by hiding necessary legitimate agents; BT owner must settle that authority model.
Sequence operation/scan and pairing recovery separately from external-client OBEX
recovery. CQ-02 needs operation/scan/prompt safety, not a new OBEX UI. Preserve
incoming-agent opt-in; do not enable it or add file-transfer presentation.

**Retain/acceptance:** producer fake-backend/private-bus/socket cases for lost last
terminal, status/event inversion, duplicates/old lifetimes, foreign owners, late
registration/cleanup and surviving peers. Actual Qt extend
`shelllist/tests/qml/tst_bluetooth_stream_recovery.qml` and
`shelllist/tests/qml/tst_bluetooth_recovery.qml`: close clears inputs, late recovery
does not resurrect them, pairing responses retain their captured ID, absent
outcomes stay unknown and recovery makes zero effect calls. Extend the existing
BT native probe through production routing; no BlueZ/OBEX hardware fixture.
**Gate:** existing transport-rollout blocker; prerequisite to CQ-02, not a new
conversion requirement retroactively claimed complete.

### CQ-02 — BT native rescan recommendation, local browsing intent

**Owner/files:** BT: `bt-daemon/src/daemon/operation.rs`,
`bt-daemon/src/daemon/scan.rs`, `bt-daemon/src/protocol.rs`;
Shelllist: `shelllist/typescript/bluetooth/BluetoothFlow.ts`,
`shelllist/bluetooth/BluetoothOperationController.qml`,
`shelllist/bluetooth/BluetoothController.qml` and generated JS/BT contracts.
**Prerequisite:** CQ-01 ordered owner-correlated terminal evidence.

**Contract/work:** publish an explicit native scan-recovery recommendation on a
failed pair (reason, captured adapter identity, originating operation identity),
computed from the native failure category. QML retains active All-devices intent,
selection and one outstanding scan guard; it no longer matches error codes.
Consume a fresh terminal recommendation at most once for that captured UI intent;
status/gap/reconnect recovery may update feedback but must not execute it. Native
scan admission still validates adapter/power and preserves other owners' leases.
Separate automatic read reconciliation from active-view scan-start intent so a
snapshot refresh cannot accidentally retry a terminal operation.

**Retain/acceptance:** producer fake pair-unavailable versus other failure,
wrong adapter, cancelled/foreign/expired operation and shared scan lease cases;
actual Qt native fields/navigation plus duplicate terminal, UI closed/My-devices,
powered-off, existing scan and quiet status recovery cases. Require explicit
Refresh/scan command to work after failure; never loop pair or scan from recovery.
Use `tst_bluetooth_recovery.qml` plus a focused new Qt case in that suite.
**Gate:** separate project-completion work; CQ-01 remains the rollout blocker.

### CQ-03 — BT native list facts; remove legacy policy reconstruction

**Owner/files:** BT: `bt-daemon/src/model.rs`,
`bt-daemon/src/bluez/snapshot.rs`, `bt-daemon/src/bluez/snapshot/assembly.rs`,
`bt-daemon/src/frontend_contract.rs`; Shelllist:
`shelllist/typescript/bluetooth/BluetoothFlow.ts`,
`shelllist/bluetooth/BluetoothProvider.qml`,
`shelllist/bluetooth/BluetoothController.qml`, `shelllist/bluetooth/BtApi.js`
and generated BT contract inputs/outputs.

**Contract/work:** add native view-scope membership/rank score and duplicate-name
adapter context to device presentation, computed with current management policy
in the same published snapshot. QML chooses My/All and asset/copy, passes the
native score to existing Rust search, and retains stable keys. Remove adapter-
derived radio and absent-policy trust override. Validate required policy/presentation
metadata at the boundary; unsupported producers remain unavailable, not defaulted.
No new search process, native field draft or persisted selection policy.

**Retain/acceptance:** real producer serializers: blocked/recent/paired/connected,
relative RSSI, duplicate names across adapters, policy changes and missing metadata;
actual Qt extend `tst_bluetooth_signal.qml`, `tst_bluetooth_recovery.qml` and
`tst_bluetooth_stream_recovery.qml` for order/membership, stable selection, active
rename/adapter drafts, no extra writes and malformed projections retaining state.
**Gate:** separate project-completion; current required-radio guard is a retained
prerequisite, not a newly discovered rollout failure.

### CQ-04 — NM private prompt recovery/authority prerequisite

**Owner/files:** NM: `nm-daemon/src/daemon_secret.rs`,
`nm-daemon/src/daemon_secret/lifecycle.rs`,
`nm-daemon/src/daemon_runtime/subscriptions.rs`, `nm-daemon/src/daemon_event.rs`,
`nm-daemon/src/protocol.rs`, private socket/SecretAgent tests; frontend NM:
`shelllist/wifi/WifiBackend.qml`, `shelllist/wifi/WifiPromptController.qml`,
`shelllist/wifi/WifiConnectionController.qml` and generated NM contracts.

**Contract/work:** close the matrix's private `wifi.secret` row: authorized current
prompt/status recovery, remaining deadline, filtered ordering, cancellation/delivery/
persistence identity and quiet terminal loss. A new owner cannot recover another
owner's secret authority. Collection renewal remains separate from prompt/operation
observers. Missing acceptance/storage evidence is not link success or disk storage.
Coordinate with the NM owner rather than invent a frontend private-prompt cache.

**Retain/acceptance:** native fake NM calls, private buses with activation disabled:
foreign/retired owners, expiry racing reply, saved/temporary/mixed policy, missing
last cancellation/delivery/persistence, disconnect and peer survival. Actual Qt
extend `tst_wifi_operations.qml`, `tst_wifi_prompt.qml` and
`tst_wifi_stream_recovery.qml`; preserve drafts during collection renewal, clear
on real expiry, ignore foreign replies, block duplicate submit, never auto-connect
or provide secrets during recovery. Extend existing private NM native probe for
prompt observer lifetime; no credential provider files or real NetworkManager.
**Gate:** existing transport-rollout blocker; CQ-05 consumes this authority model.

### CQ-05 — NM complete descriptors and one submitted-form normalization

**Owner/files:** NM: `nm-daemon/src/model/prompts.rs`,
`nm-daemon/src/model.rs`, `nm-daemon/src/daemon_secret.rs`,
`nm-daemon/src/daemon_connect.rs`, `nm-daemon/src/nm/wifi_settings.rs`,
`nm-daemon/src/contract.rs`, `nm-daemon/src/contract/frontend_contract.rs`;
Shelllist: `shelllist/typescript/wifi/WifiPromptPolicy.ts`,
`shelllist/wifi/WifiPromptController.qml`, `shelllist/wifi/WifiCredentialDialog.qml`,
`shelllist/wifi/WifiConnectionController.qml`, generated JS/NM contracts.
**Prerequisite:** preserve CQ-04 authority/expiry contract; descriptors alone do
not close prompt lifecycle recovery.

**Contract/work:** extend enterprise and SecretAgent descriptors to native
allowlisted fields with requiredness, secret/input kind, initial/default value,
encoding (including EAP list), supported storage choices and descriptor version.
Hidden descriptors already exist: reuse their vocabulary, do not duplicate modes.
Native normalizes the captured raw form only on explicit submission through the
existing connect/secret dispatch (a proposed raw-form DTO in `daemon_connect.rs`);
legacy structured clients remain supported. Do not introduce an extra plaintext
secret validation RPC or weaken certificate/storage checks. Reject missing/
unsupported descriptor versions explicitly; remove JS defaults/key guessing and
secret-name heuristics only after negative fixtures establish safe mismatch behavior.

**Retain/acceptance:** native serialization and dispatch parity for enterprise,
TLS/private keys, unknown/plugin secret keys, PIN masking classification, all
requested values, optional blanks/EAP splitting, NOT_SAVED and mixed ownership;
fakes must prove no persistence/activation before submission. Actual Qt extend
`tst_wifi_prompt.qml`, `tst_wifi_operations.qml`, `tst_compact_confirmations.qml`:
native Enter and button submit, draft retained on failed send, expiry/close clears,
required-storage cannot uncheck, unsupported/malformed descriptor cannot open a
fallback form, Forget challenge retained, no backend write while typing/Tab browsing.
**Gate:** separate project-completion; descriptor incompatibility is a blocker to
shipping this conversion, not an independent reason to gate all socket adoption.

### CQ-06 — Updates producer-owned wire schemas, retained read transactions

**Owner/files:** bar: `bar-daemon/src/updates/overview.rs`,
`bar-daemon/src/updates/history.rs`, `bar-daemon/src/updates/catalog.rs`,
`bar-daemon/src/protocol.rs`, proposed `bar-daemon/src/protocol/update_wire.rs`,
`bar-daemon/src/frontend_contract.rs`; Shelllist:
`shelllist/bar/UpdateValidation.js`, `shelllist/bar/UpdateController.qml`,
`shelllist/tests/qml/tst_updates.qml` and generated bar contracts/fixtures.
No update-daemon Python change and no new deployment effect API.

**Contract/work:** introduce typed read-side overview/page/log DTOs using existing
native records and normalization. Export real request/result schemas (bounds,
nullable/omitted fields, IDs, timestamp domains), not JSON examples. Wire generated
result validation into the owned update completion before publication; an Io-wide
result-validation hook, if desired, belongs to the shared Io owner, not this panel.
Use producer-generated schemas for static checks. Retain run-target/log identity,
page/total/revision relationships and staged-window checks locally where they
refer to the current UI transaction. Delete redundant predicates only individually,
with parity vectors. Native schema refinement/source must represent cross-field
invariants; deriving serde alone is insufficient.

**Retain/acceptance:** producer Rust DTO/serializer tests plus existing overview/
history tests for unavailable vs empty, zero history timestamps vs positive bounded
overview timestamps, stale last-known releases, failed log reads and private paths.
Producer/Qt parity must include omitted vs null, UTF-8 bytes vs JS UTF-16/codepoint
lengths, control characters, integer bounds and relational failures. Actual Qt
`tst_updates.qml`: malformed reply never replaces good state; owned reader alone
retires; exact-run rejects another run; stale cursor restarts once; partial pages
never publish; cached failed logs require explicit retry. Keep settings native
Enter/Tab save, Escape discard and no update/clipboard effect except recorded
explicit copy intent. **Gate:** separate project-completion, not transport rollout.

### CQ-07 — Updates semantic facts without moving the reviewer into Rust

**Owner/files:** bar: `bar-daemon/src/updates/catalog.rs`,
`bar-daemon/src/updates/overview.rs`, `bar-daemon/src/updates.rs`,
`bar-daemon/src/updates/history.rs`, CQ-06's proposed update wire module;
Shelllist: `shelllist/bar/UpdatePresentation.js`,
`shelllist/bar/UpdateHistory.js`, `shelllist/bar/UpdateController.qml`,
`shelllist/tests/qml/tst_updates.qml`, generated bar contracts/fixtures.
**Prerequisite:** CQ-06 typed read-side projection; reuse existing Rust status
crate outcome semantics unchanged (do not edit/fork excluded updater policy).

**Contract/work:** supply native semantic counts/group classifications, reconciled
running/unknown timing facts, conservative routine-fold eligibility and current
lane/candidate summary states. Keep current readiness distinct from historical
staged outcome; use native comparison/recovery, never version-string arithmetic.
QML retains local-calendar display formatting, loaded-only consecutive folding,
selected/expanded anchors, local labels and copy formatting. Raw full records
remain available. Explicitly define which timezone identifies same-day folding
and relative-date refresh before moving date membership; do not bake a second
calendar into the producer just to reduce JS.

**Retain/acceptance:** producer changed+failed, held, cancelled, abandoned-running,
equal-time non-recovery, later component-specific recovery, readiness-read error,
unknown upstream/graph, stale comparison and manual partial deployment cases.
Actual Qt `tst_updates.qml`: Now independent of history/search, no inference of
booted/activated from ready/staged, no hidden failures, loaded-only fold expansion,
full-path copies, midnight/date-boundary and unknown-duration cases, zero execution
calls, retained selection/viewport and settings drafts. Labels/Help add no stops.
**Gate:** separate project-completion; calendar-zone decision remains explicit U.

### CQ-08 — Native media action/identity facts, local assets

**Owner/files:** bar: `bar-daemon/src/media.rs`,
`bar-daemon/src/media/source.rs`, `bar-daemon/src/media/browser_identity.rs`,
`bar-daemon/src/model.rs`, `bar-daemon/src/protocol.rs`,
`bar-daemon/src/protocol/session_controls.rs`, `bar-daemon/src/media/tests.rs`;
Shelllist: `shelllist/typescript/bar/BarMediaPresentation.ts`,
`shelllist/bar/MediaControls.qml`, `shelllist/bar/SystemEntries.js`,
`shelllist/bar/MediaPlaybackCard.qml`, generated JS/bar contracts and fixtures.

**Contract/work:** add resolved transport kind/operation/offset and enabled facts
based on native control mode, content kind and capability. Publish service/origin
facts for existing exact desktop identities as well as validated sources;
source-less app labels must not become authoritative content kind. Keep logo/icon
aliases, localized wording, distinct label composition and passive card geometry
in QML. Original player IDs remain routing/pin identities; never parse/open/fetch a
content or artwork URL to discover semantics. Revalidate commands in the native
execution path; displayed capability is not authority for a replacement owner.

**Retain/acceptance:** producer pure/source/fake-MPRIS tests for music/spoken/
unknown, automatic/explicit modes, partial capabilities, owner change, ambiguous
browser/service, malformed URLs and source removal; no network enrichment enabled.
Actual Qt extend `tst_media_chip.qml` and `tst_system_choosers.qml`: all bar controls
remain direct, disabled actions do not act, opener never transports, inspected
non-active Raise stays distinct, source refresh cannot save pin/mode drafts,
Enter/Tab save and Escape discard unaffected, missing projections fail closed.
**Gate:** separate project-completion; no existing bar ordering stage redo.

### CQ-09 — Media timing contract: evidence/decision before conversion

**Owner/files:** bar: `bar-daemon/src/media.rs`, `bar-daemon/src/media/tests.rs`,
`bar-daemon/src/model.rs`; Shelllist:
`shelllist/typescript/bar/BarMediaPresentation.ts`,
`shelllist/bar/MediaPlaybackCard.qml`, `shelllist/tests/qml/tst_system_choosers.qml`.
Native timing projection/schema changes follow CQ-08 and an owner-approved decision.

**Finding/decision needed:** helper comment says daemon samples every two seconds.
Read producer monitor is driven by owner/property/seek/enrichment changes;
`media.rs`'s two-second sleep is reconnect backoff, not a periodic position sampler.
`daemon/tasks.rs` launches that monitor, not an additional media sampler. Missing
MPRIS Position currently becomes zero, indistinguishable from a real zero.
Do not claim a timing migration is equivalent on that assumption.

**Bounded work/acceptance:** fake quiet playing MPRIS player plus controlled clock:
prove observation cadence, missing Position/Rate versus true zero, pause/seek,
rate changes, stale/disconnected data and clock jumps. Actual Qt assert passive
elapsed/remaining/progress, no seek/effect, hidden/disconnected timer stop, unknown
not zero and bounded extrapolation. Then choose/document one contract: native
validity/time labels at a bounded native cadence, or native validity/freshness/
extrapolation parameters with QML-only visual interpolation. The latter must not
reimplement domain thresholds or claim an interpolated value was observed.
Keep pixel fraction/clamping/animation local in either design. No decision made
by this audit. **Gate:** separate project-completion, **U pending timing evidence**;
not a bar socket-rollout blocker or permission to start another polling service.

### CQ-10 — Bar telemetry: reuse native unknown/unit facts

**Owner/files:** bar: `bar-daemon/src/presentation.rs`,
`bar-daemon/src/model.rs`, `bar-daemon/src/battery/mod.rs` and presentation tests;
Shelllist: `shelllist/typescript/bar/BarStatusPresentation.ts`,
`shelllist/typescript/bar/BarIndicators.ts`,
`shelllist/typescript/bar/BarOsdPresentation.ts`,
`shelllist/bar/BarBatteryGauge.qml`, generated JS/bar contracts/fixtures.

**Contract/work:** consume existing `battery.display.power` rather than inventing
0 W; extend native display facts for estimate/health/cycles/state where missing.
Only explicit native fully-charged state yields that semantic label; plugged
100% with paused/inhibited state is not enough. Keep continuous fill geometry,
known-only animation, warning/critical tone, glyph thresholds and icon assets
local. For OSDs distinguish absent/invalid reading from valid zero before formatting
text; `percent` may still clamp pixels but cannot manufacture a known observation.
Do not change battery thresholds, calibration/critical guards or admission.

**Retain/acceptance:** producer unavailable vs true zero power, `power_available`
false, negative/nonfinite readings, charging/paused/inhibited/full state and native
warning/critical policy witnesses. Actual Qt add focused consumer cases to
`tst_bar_material.qml` and `tst_bar_recovery.qml`: unknown gauge/tooltip/OSD, valid
zero, native state marks and baseline recovery without replaying an OSD edge.
Existing battery transaction/safety suites remain. **Gate:** separate project-
completion; this is presentation correctness, not evidence of a transport failure.

### CQ-11 — Bar native clock publication, not host-timezone fallback

**Owner/files:** bar: `bar-daemon/src/timezone.rs`,
`bar-daemon/src/timezone/tests.rs`, `bar-daemon/src/model.rs`,
`bar-daemon/src/activity/presentation.rs`, `bar-daemon/src/protocol.rs`;
Shelllist: `shelllist/typescript/bar/BarStatusPresentation.ts`,
`shelllist/bar/BarClockButton.qml`, `shelllist/bar/BarContent.qml`, generated
JS/bar contracts/fixtures and `shelllist/tests/qml/tst_timezone_clock.qml`.

**Contract/work:** reuse the existing native clock-formatting primitive to publish
bar date/short-date/time/offset facts at minute boundaries under the existing
timezone domain publication clock. Define one native clock owner/cadence; do not
start a per-consumer producer or substitute an arbitrary selected city's clock.
QML renders last accepted reading; unavailable/missing metadata stays unknown,
not host local time or guessed UTC. Remove duplicate UTC arithmetic and local
clock updater only when native minute publication/mismatch tests exist.

**Retain/acceptance:** producer controlled-time DST, offset/date/year rollover,
fractional offsets, timezone change, unavailable zone and publication atomicity;
actual Qt `tst_timezone_clock.qml` plus `tst_bar_publication.qml`: changing observed
timezone updates without restart, stale publications cannot roll back, disconnected
clock freezes/unknown per contract, no fallback host-timezone calculation, same
single action/accessibility and no editable stops. **Gate:** separate project-
completion; native bar stream recovery is a retained prerequisite.

### CQ-12 — NM-owned network-kind evidence for the bar

**Owner/files:** NM: `nm-daemon/src/model.rs`,
`nm-daemon/src/daemon_status.rs`, `nm-daemon/src/contract.rs` and native status tests;
Shelllist: `shelllist/typescript/bar/BarStatusPresentation.ts`,
`shelllist/bar/BarController.qml`, `shelllist/wifi/WifiController.qml`,
`shelllist/tests/qml/tst_bar_material.qml`, generated JS/NM fixtures.
**Prerequisite:** NM owner settles full-status read/event ordering per stream matrix.

**Contract/work:** define explicit link/status evidence, including unknown/
transition and strength availability, at the NM-owned boundary. Current active
Wi-Fi status with missing AP is not proof of Ethernet. A real multi-link/Ethernet
summary, if desired, must use the existing inventory owner and is a separate API
extension, not inferred in bar-daemon or QML. Keep status glyph/name composition
local and retain portal authorization/intent; disconnected/unknown cannot auto-open
Sign in. **Retain/acceptance:** native status transitions with active-but-no-AP,
missing strength, inactive and inventory distinctions; Qt verified tooltip/icon
facts, no fake 0%, missing metadata, stale status reply and no effect dispatch.
**Gate:** conversion separate project-completion; underlying NM status ordering
qualification remains an existing transport-rollout blocker. Exact link summary
scope is **U until NM owner agrees**, not a claim the bar supports Ethernet today.

### CQ-13 — Power-profile cycling: native eligible next target

**Owner/files:** bar: `bar-daemon/src/power.rs`,
`bar-daemon/src/power/automation.rs`, `bar-daemon/src/model.rs`,
`bar-daemon/src/protocol/control_wire.rs` and power tests; Shelllist:
`shelllist/typescript/bar/BarStatusPresentation.ts`,
`shelllist/bar/BarController.qml`, generated JS/bar contracts/fixtures.

**Contract/work:** native projection supplies the eligible next manual profile
(or absent), computed from supported available profiles and current state.
The explicit bar command submits that captured target through existing set;
native revalidates under its power-envelope owner. Do not cycle unknown extension
names into `set_profile`, which accepts only saver/balanced/performance. Local
ordering for an editable choice UI remains Q; no automatic retry/cycle on refresh.

**Retain/acceptance:** fake power service missing/current/one/two/three/unknown
profiles, removed target, manual holds/automation and failure; Qt actual bar command
routes one set, no target disables it, stale/missing projection cannot select an
inferred default, acknowledgement/error unchanged. Use `tst_bar_material.qml` and
existing battery power transaction owners, no host PowerProfiles service.
**Gate:** separate project-completion, not bar transport rollout.

### CQ-14 — Retain Core/Model; bounded strict-boundary review only

**Owner/files:** shared Core owner only:
`shelllist/qml/Shelllist/Core/Model.js`,
`shelllist/qml/Shelllist/Core/ProviderRegistry.qml`,
`shelllist/qml/Shelllist/Core/ResultStore.qml`,
`shelllist/tests/qml/tst_search_service.qml`,
`shelllist/tests/qml/tst_surface_actions.qml`.
**Contract/work:** close blanket Rust conversion as not justified. If permissive
coercion is questioned, first add actual Qt vectors at raw construction versus
trusted normalized handoff (duplicate IDs, invalid primary references, disabled
execution, malformed scores/booleans). Document callers that require coercion;
only then propose a strict-boundary change, separately reviewed by Core owner.
No new daemon ABI or Rust UI state merely to shrink JS.
**Producer acceptance:** retain native search tests using actual `SearchItem` and
actual producer contract parity; no producer changes required. Qt must preserve
accepted rank window, disabled command slots, stable result keys/selection and
no extra field stops. **Gate:** retain decision/separate optional hardening, not
transport blocker. U remains whether coercion is a demonstrated defect, not
whether chooser transactions belong in QML.

### CQ-15 — Application Close classifier: reuse canonical submitted action

**Owner/files:** frontend app owner:
`shelllist/launcher/ApplicationPresentation.js`,
`shelllist/launcher/ApplicationOperations.qml`,
`shelllist/launcher/ApplicationLifecycle.js`,
`shelllist/tests/qml/tst_application_actions.qml`.
Native `ApplicationAction` and `OperationResult.action` already exist; no new app
producer policy or API required.

**Contract/work:** capture canonical submitted action from existing params at
start (or reuse the existing checked lifecycle mapper), and use that for both
active and terminal no-handoff classification. Remove the separate string-prefix
classifier from presentation after equivalent coverage. Keep all remaining
presentation helpers local. Continue validating target/action/operation identity
and native revision; never trust irrelevant launch metadata on a Close receipt.

**Retain/acceptance:** actual Qt Close/CloseWindow accepted/running/completed/
failed/cancelled/unknown, malformed/missing close observation, unrelated launch
receipt, status recovery, reopened/browsed view and duplicate outcomes; chooser
must not dismiss or optimistically remove windows. Keep row-command focus recovery
and explicit retry. Producer acceptance reuses actual typed action serialization
and fake close-observation tests in `app-daemon/src/service/action.rs` and
`app-daemon/src/service/action/close.rs`, with private session/socket parity;
no real launch/compositor. **Gate:** separate small project-completion cleanup,
not an app transport-rollout blocker.

## Acceptance execution and handoff

Implementation owners must refresh the actual producer-generated fixtures and
bindings together: producer `test_support` exports, frontend `contracts` API
fixtures and `tests/qml/fixtures` where present; generated `*Protocol.generated.js`
and TS outputs are not independent source policy. Use
`shelllist/tools/build-typescript.mjs` and
`shelllist/tests/generate-protocol-bindings.sh`, then
`shelllist/tests/check-generated-contracts.js` and matching `cargo xtask contract`
checks. Missing producer/debug generator binaries are a blocker to report, not
permission to use installed/original-checkout stale binaries.

Exact generated companion ownership (update only the affected family's outputs):

| Family | Producer-owned checked input | Frontend generated/fixture companions |
| --- | --- | --- |
| BT | `bt-daemon/test_support/bt-api-v1.json` | `shelllist/bluetooth/BtProtocol.generated.js`, `shelllist/contracts/bt-api-ui-contract.fixture.json`; TS output `shelllist/bluetooth/BluetoothFlow.js` |
| NM | `nm-daemon/test_support/contract-v1.json`; live registry in `nm-daemon/src/protocol.rs` | `shelllist/wifi/NmProtocol.generated.js`, `shelllist/contracts/nm-api-ui-contract.fixture.json`; TS output `shelllist/wifi/WifiPromptPolicy.js` |
| Bar | `bar-daemon/test_support/bar-api-v1.json` | `shelllist/bar/BarProtocol.generated.js`, `shelllist/contracts/bar-api-ui-contract.fixture.json`, `shelllist/tests/qml/fixtures/bar-reads.json`, `shelllist/tests/qml/fixtures/bar-controls.json` as affected; TS outputs `shelllist/bar/BarIndicators.js`, `shelllist/bar/BarMediaPresentation.js`, `shelllist/bar/BarStatusPresentation.js`, `shelllist/bar/BarOsdPresentation.js` |
| App | `app-daemon/test_support/app-api-v1.json` | `shelllist/launcher/AppProtocol.generated.js`, `shelllist/contracts/app-api-ui-contract.fixture.json`, `shelllist/tests/qml/fixtures/app-events.json`, `shelllist/tests/qml/fixtures/app-replies.json` only if their existing contract changes (CQ-15 should not require an API change) |

Native probe fixture owners are `bt-daemon/src/daemon/tests/socket/probe.rs` with
`shelllist/tests/e2e/unix-jsonl.qml`,
`nm-daemon/src/daemon/socket/tests/probe.rs` with
`shelllist/tests/e2e/nm-unix-jsonl.qml`,
`bar-daemon/src/daemon/socket/tests/native.rs` with
`shelllist/tests/e2e/bar-unix-jsonl.qml`, and
`app-daemon/tests/session/socket.rs` with `shelllist/tests/e2e/app-unix-jsonl.qml`.
These are extension points, not proof of the newly specified semantic cases.
Shared generator/runtime files remain framework/Io-owned:
`daemon-framework/crates/shelllist-daemon-core/src/bin/shelllist-protocol-js.rs`,
`daemon-framework/crates/shelllist-daemon-core/src/schema_validation.js`,
`shelllist/qml/Shelllist/Io/ProtocolValidation.generated.js` and
`shelllist/qml/Shelllist/Io/DaemonBackend.qml`. No panel-private generator/runtime
fork or schema fallback is acceptable; request shared changes with a failing vector.

All heavy checks below must use the orchestration `check.sh` (absolute path in
the delegated task contract), a bounded `timeout`, private fixtures and matching
family environments. Example templates, **not audit runs**:

```sh
# From the changed producer, after inspecting fixtures for host-service access:
$CHECK timeout 900 nix develop . --no-write-lock-file -c bash -c \
  'set -e; cargo test --locked; cargo clippy --locked --all-targets -- -D warnings; cargo fmt --check'
# From shelllist, using matching Qt/fonts/offscreen environment:
$CHECK timeout 900 nix develop . --no-write-lock-file -c bash -c \
  'set -e; tests/run-qml-tests.sh; tests/run-qmllint.sh; node tools/build-typescript.mjs --check; node tests/check-generated-contracts.js'
# Newly tracked inputs must first be staged with git add -N; no preflight bypass:
$CHECK timeout 1800 ../daemon-framework/tools/local-build build \
  --attr checks.x86_64-linux.qmlTests . --no-link --print-build-logs
```

Set `CHECK` to the required helper, not a replacement wrapper. Also run sibling
snapshot preflight, `buildInputs`, relevant `btDaemonContract`/`nmDaemonContract`/
`barDaemonContract`/`appDaemonContract`, surface checks and the affected explicitly
invoked private native probes as documented in `shelllist/tests/README.md`.
Inspect constructors: a test name containing "fake" does not ensure no host bus,
service activation, artwork fetch, clipboard publication or notification effect.
Do not run the e2e QML fixtures standalone. Private buses must disable activation;
recording publishers and fake accepted work retain admission/cancellation semantics.

For native evidence record source heads/dirty inputs, snapshot graph identity,
compiler/Qt/Quickshell versions, binary path/hash and build mode, exact command,
deadline, logs and explicit skips. A source-only audit cannot supply binary
identities. Mock Qt transport tests are actual Qt interaction evidence, not native
producer/backpressure evidence; pair them with producer-owned serializers and
private production-routing tests. Existing renderer skip is not a pass.
No latency/memory benchmark is needed for these ownership tickets; if requested,
provide a separate serial matched-release recipe, not concurrent measurements.

### Completion and uncertainty boundaries

- CQ-01/CQ-04 and the existing NM full-status recovery gates are **transport
  rollout prerequisites** already recorded in the matrix. This audit neither
  implements nor certifies them. Do not hold unrelated already-qualified adapters
  hostage to a blanket JavaScript rewrite.
- CQ-02/03/05–13/15 are separate Rust/QML project-completion work. Each has its own
  matching protocol and negative-path gate before shipping its conversion.
  CQ-14 is retain, with optional separately evidenced hardening.
- Open owner decisions: BT prompt observation/response authority; NM prompt recovery
  and complete field metadata; schema cross-field/Unicode-length parity and any
  shared generator/Io extension; media sampling/interpolation; update calendar-zone
  semantics; NM Wi-Fi versus multi-link summary scope. These are explicit U items,
  not defaults selected by this audit.
- No source changes outside this audit, no lockfiles, activation, deployment,
  default switch, service restart, real credential/clipboard/hardware work, live
  desktop testing or updater Python conversion. Approval and integration remain
  with the coordinator and domain owners.
