# Plan: move domain work out of Shelllist

Status: implementation in progress, based on the
[2026-09-13 boundary audit](../daemon-boundary-audit.md).

## Implementation ledger

- Phase 1 implemented: native bounded QR rendering, explicit credential requests,
  metadata-only availability, profile-version fencing, no frontend QR files/parser.
  Validation: 109 nm-daemon tests passed (3 ignored), Clippy, 196 QML tests,
  QML lint and NM API/binding contract checks. Not deployed.
- Phase 2 implemented: bounded daemon-side search using the shared native matcher,
  authenticated owner/query/generation-bound cursors with 120-second expiry and
  explicit invalidation on revision changes; no retained snapshot leases. QML
  requests visible pages only and cannot merge superseded replies. Native search
  is capped at 5,000 recent entries and two concurrent workers. Validation: 48
  clip-daemon tests, 4 matcher tests, 197 QML tests, Clippy, QML lint and clip API
  contract checks. Not deployed.
- Phase 3 implemented: bar-daemon owns cached discharge-energy bins, observed
  coverage, actual-limit ETA scaling and forecast status. Native telemetry now
  distinguishes unavailable power from measured zero; QML only renders supplied
  values. Validation: 114 bar-daemon tests passed (1 ignored), Clippy, 197 QML
  tests, chart JS tests, QML lint and bar API fixture checks. Not deployed.
- Phase 4 implemented: native typed Hyprland batch parsing/rule resolution,
  bounded replies and one bar-daemon geometry cache. Subscription guards control
  demand; owner loss/cancellation drops demand, and no interested views means no
  geometry polling. QML retains only screen-relative pixel clamping. Updated
  app-daemon's vendored adapter as well. Validation: native parser/socket tests,
  a successful read-only live compositor probe, bar-daemon/app-daemon suites,
  Clippy, 191 QML tests, QML lint and bar API fixture checks. No deployment.
- Phase 5 implemented: app-daemon returns full-window, observed-duration-weighted
  summaries on every history page, with availability, coverage and preserved
  network peaks. QML freezes pagination bounds, validates summary revision/window,
  and no longer scans history for statistics or guesses legacy availability.
  Validation: 68 app-daemon tests passed (3 opt-in tests ignored), Clippy, 191 QML
  tests, JS history/availability tests, QML lint and app/resource fixture checks.
  Not deployed.
- Phase 6 pending.

## Goal and rule

Shelllist should express **view intent and render authoritative results**. Domain
daemons should own system/protocol interpretation, domain calculations, secrets,
consistent data snapshots, persistence and operation execution. The shared Rust
bridge owns transport mechanics, not domain-specific logic.

Do not move work merely because it contains JavaScript or a loop. In particular,
keep pixel geometry, rendering, focus, selection, unsaved drafts, localization,
view filtering/grouping and immediate input feedback in QML. Daemons must still
validate mutations independently of that feedback.

## Order

| Phase | Work | Destination | Why this order |
| --- | --- | --- | --- |
| 0 | Finish coordinated release of the existing routing fix | Framework + five client binaries + Shelllist | Prevent mixing new routed QML with old bridges |
| 1 | Wi-Fi share secrets and QR artifact lifecycle | `nm-daemon` | Reduce credential lifetime and UI-dependent cleanup |
| 2 | Clipboard snapshot consistency, paging and domain search | `clip-daemon` | Eliminate mixed-revision results and frontend catalog reconstruction |
| 3 | Battery energy integration and forecast semantics | `bar-daemon` | Remove substantial domain calculations from the QML engine |
| 4 | Hyprland state parsing and workspace-rule resolution | `shelllist-hyprland`, exposed through `bar-daemon` | Remove a duplicate protocol parser and repeated frontend subprocesses |
| 5 | Application resource-window statistics | `app-daemon` | Centralize coverage/mean/peak semantics and avoid repeated paint-time scans |
| 6 | Lunar phase and solar estimates | `bar-daemon` activity/weather | Lower-risk cleanup of scientific estimates in presentation helpers |

Phases 1–6 can be developed independently after the transport contract is stable.
Deliver one end-to-end migration per release rather than accumulating a large
cross-daemon flag day. Do not introduce another general-purpose daemon.

## Phase 0 — establish a deployable baseline

The Rust routing implementation and regression tests are already committed
locally. Deployment and release-pin updates remain separate work.

1. Verify the framework source and app-daemon's vendored snapshot agree.
2. Advance the daemon/framework inputs used by the release, including daemon
   checkouts whose standalone builds pin older framework revisions.
3. Rebuild all five client binaries and the QML config against the same routing
   contract; run the candidate cross-repository gate before advancing Shelllist's
   final release lock.
4. Coordinate activation so the new QML never runs with old client binaries.
5. Smoke-test open/close/reopen, paging, cancellation, late subscription replies,
   daemon replacement and failed-generation non-replay.

**Exit:** the deployed version, not just the worktree, uses the Rust-owned routing
path. The original 20,000-request QML regression remains green.

## Phase 1 — Wi-Fi sharing without frontend secret files

### Move

From `wifi/process/WifiQrService.qml`, `wifi/WifiQr.js`, and the credential-bearing
cache in `wifi/ShareAvailabilityController.qml`:

- QR generation from validated credentials;
- structured display fields rather than reparsing a `WIFI:` payload;
- secret/artifact lifetime and cleanup policy.

### Daemon contract

Use the existing share API where possible; exact new method names are to be
chosen alongside its protocol registry/fixtures.

- An availability-only request returns capability/reason, not the password,
  complete QR payload or an image containing the credential.
- An explicit share request resolves a stable network/profile target, checks its
  current revision, and returns an in-memory image plus explicitly requested
  display/copy fields. Include target/revision identity so stale replies can be
  rejected by the view.
- Prefer bounded SVG/image bytes over a filename. If files are unavoidable,
  require unique private caller-scoped leases, expiry, release and orphan cleanup.
- Keep secret bytes out of arguments, logs, generic event broadcasts and ordinary
  network snapshots. Fetching a readable credential is not permission to retain
  it indefinitely in a frontend cache.

### UI after migration

The UI opens the share dialog, displays the returned image, handles explicit copy
commands and clears secret-bearing view state on close or selection change. An
interactive scanner may remain UI-launched; its payload goes to the daemon for
validation. Delete the QR renderer/cleaner subprocesses and password parser.

**Tests:** open/secured/hidden networks; escaped SSIDs/passwords; unavailable
credentials; profile changes during a request; overlapping dialogs; close before
reply; UI/daemon crash; secret-free logs/argv; bounded payloads; no residual files.

## Phase 2 — authoritative clipboard snapshots

### Move

From `clipboard/ClipboardController.qml::requestHistory/applyHistory`:

- keeping a coherent multi-page history view;
- offset/cursor advancement and revision consistency;
- reconstructing/searching the full catalog solely to populate the UI.

### Daemon contract

1. Provide a query-scoped, revision-bound snapshot/cursor. The daemon chooses
   snapshot retention or explicit invalidation; it must not silently combine
   revisions.
2. Return bounded pages with stable entry IDs/revisions, next cursor, completion
   state and an explicit stale/expired-cursor error.
3. Bound snapshots per caller, page sizes, retained memory and lease duration.
   Release on cancellation, caller disappearance and expiry.
4. Put clipboard-domain indexing/query execution next to the clipboard store.
   Preserve current fuzzy-search behavior deliberately: evaluate parity with the
   existing Rust matcher before switching. Reuse a pure matcher if necessary;
   do not copy a second ranking algorithm into QML or the transport framework.
5. Keep mutation-time entry revision validation independent of snapshot lifetime.

### UI after migration

The UI holds the requested query, selection and visible pages; it requests more
rows as needed and reconciles delegates. It does not fetch thousands of mutable
entries to infer an authoritative history snapshot. A stale cursor triggers an
explicit read refresh while preserving selection/drafts by stable identity,
never a replay of a mutation.

**Tests:** insert/delete/reorder between pages; identical local IDs for concurrent
consumers; changing search during a request; cursor expiry/restart; no-progress
cursors; bounded resources; cancellation; search parity; stale mutation rejection.

## Phase 3 — daemon-owned battery derived data

### Move

From `battery/BatteryHistory.js`:

- discharge eligibility and gap/transition rules used for energy;
- trapezoidal Wh integration, observed-time bins and totals;
- forecast validity limits and ETA scaling to the current charge target.

### Daemon contract

Extend battery history/current-state payloads with bounded energy bins, totals,
observed duration and a typed forecast: valid/estimating/unavailable status,
percentage, target, active limit, estimated duration and approximation/source
metadata. Specify aggregate-pack versus device scope explicitly.

Compute these from the same daemon-owned samples and protection policy, with
caching tied to sample/policy revisions rather than UI repaint frequency. Missing
or invalid measurements must remain distinguishable from measured zero.

### UI after migration

Keep mapping normalized time/value data to pixels, charge/energy colors, line
segments, hover lookup, projection painting and localized duration labels.
Remove the superseded integration/forecast helpers; no JavaScript policy fallback.

**Tests:** port existing energy/forecast cases into Rust; sleep/restart/clock gaps;
charging/holding/discharging transitions; zero/full charge; invalid/non-finite
inputs; protection limits/one-time charging; pruning and bin boundaries. QML tests
assert alignment, hover and empty/estimating states using daemon fixtures.

## Phase 4 — native compositor-state adapter

### Move

From `qml/Shelllist/Io/process/HyprlandWorkAreaClient.qml`,
`HyprlandWorkArea.js`, and `HyprlandWorkspaceRules.js`:

- repeated `hyprctl --batch -j` snapshot acquisition;
- concatenated-JSON parsing;
- workspace-selector grammar, window counting and rule resolution.

### Daemon contract

Extend the existing Rust Hyprland adapter and publish normalized, monitor-keyed
logical work-area insets through the bar daemon. Share cached compositor state
rather than adding one process/poller per surface. Recompute on relevant events;
where Hyprland omits notifications, bound any fallback polling and activate it
only while there are interested subscribers. Include revision/availability state.

### UI after migration

Retain QScreen's authoritative logical size, final screen-relative clamping,
window placement and UI-owned layer rules. Do not move actual window rendering
or interactive window lifecycle into a daemon.

**Tests:** existing selector cases ported to Rust; fractional scale; monitor
removal; special workspaces; reservations/gaps; runtime rule changes; malformed
or unavailable compositor data; no subscribers means no avoidable polling.

## Phase 5 — canonical resource-window summaries

### Move

From `launcher/ApplicationResourceHistory.qml` and
`ApplicationResourceLaneChart.qml`:

- repeated history scans for means, peaks and data availability;
- choosing statistical coverage/validity semantics.

### Daemon contract

Return selected-window statistics alongside history, tied to the same target,
window and revision/cursor. Include per-metric mean, peak, observed duration and
coverage/availability. Define mean weighting explicitly using retained
`duration_ms` where appropriate; do not assume equal observation time per record.
Choose a bounded history/decimation limit while retaining authoritative peaks.

### UI after migration

Keep units/labels, colors, axes, pixel-dependent scale padding, filled areas and
reference-line painting. Chart data and summary must describe the same window;
a stale summary must not silently accompany newer points.

**Tests:** unequal-duration buckets; optional GPU/network/energy capabilities;
measurement gaps; partial windows; stopped applications; range changes; retained
history; summary/series consistency; no data versus zero activity.

## Phase 6 — astronomical metadata

Move `WeatherVisuals.js::moonPhase` and the solar-noon estimate in
`TimeWeatherTimePane.qml` into the bar daemon's activity/weather data. Define the
accuracy/approximation level, observation timestamp, timezone and availability;
reuse provider values when available rather than presenting approximations as
measurements.

Keep moon masking, sun-arc progress, map projection artwork and labels in QML.

**Tests:** reference dates, timezone/day boundaries, missing provider data, polar
conditions, refresh after a date change, and explicit approximation labeling.

## Not part of the migration

- Focus, navigation, selection, unsaved drafts, dialog state and user-intent
  debounce are not daemon policy.
- Input validation may remain in QML for responsive editing; it never substitutes
  for authoritative daemon validation.
- Grouping visible rows, formatting values and converting them to pixels belong
  in presentation code.
- Opening an explicitly requested browser, scanner, mixer or log viewer is a UI
  action; acquiring/parsing system state or running a persistent policy is not.
- Fuzzy cross-provider ranking can remain in the existing UI-owned Rust helper.
- Generic transport code must not acquire domain-specific method switches.

## Delivery checklist for every phase

1. Agree on the owning API, identity/revision semantics, bounds and failure states.
2. Implement daemon behavior and tests before switching the frontend.
3. Update daemon-owned fixtures/generated bindings; preserve old clients with
   additive fields/methods or explicitly version a breaking contract.
4. Switch QML and delete the old policy/parser/process path in the same delivery.
   Temporary parity tests are useful; permanent runtime dual implementations are
   not. Unsupported new data should be visibly unavailable, not guessed in JS.
5. Test cancellation, stale replies, malformed data, restart, UI disappearance and
   resource bounds. Do not assume safe Rust removes every logical/lifetime bug.
6. Run daemon tests, QML/JS tests and the candidate cross-repository gate. Verify
   the vendored framework and release inputs, then activate matching binaries and
   config. Roll back compatible client/config pairs, not QML alone.
7. Update the audit's status only after the old frontend ownership is removed.

**Definition of done:** a headless daemon client can obtain the same authoritative
result without Shelllist, closing/crashing the UI cannot corrupt its ownership
semantics, and the frontend contains no alternate implementation of that domain
policy.
