# Shelllist/daemon boundary audit — 2026-09-13

## Conclusion

The system-integration boundary is mostly established, but **domain computation
and data-lifetime ownership are not fully out of QML**. The request-routing crash
fix removes one specific failure path; it is not evidence that all remaining
frontend work is presentation-only.

This audit inspected domain controllers/helpers, process adapters, and their
counterparts in all five daemons and the shared Rust bridge. The findings below
are source-level findings, not claims that every listed risk has reproduced.

## Ownership rule

- **Domain daemons:** authoritative identity, system/protocol parsing, hardware
  and network access, permission checks, validation, persistence, numerical
  telemetry/forecast semantics, snapshot consistency, and operation execution.
- **Rust bridge:** bounded request admission, request addressing, subscription
  ownership/routing, ordered events, transport cleanup. No battery, clipboard,
  NetworkManager, or other domain switches here.
- **QML:** view intent, live view handles, selection/focus, unsaved drafts,
  responsive input validation, loading/error feedback, format/localization,
  pixel geometry, animation, and rendering daemon-supplied data.
- **UI-owned Rust helpers:** e.g. fuzzy ranking may remain in `shelllist-search`.
  Not every Rust process belongs in a system/domain daemon.

A daemon must reject invalid/stale mutations without trusting UI checks. Whether
an operation survives its caller's disappearance is an explicit daemon/lease
policy, not an accidental consequence of a QML object remaining alive.

## Already appropriately owned

| Area | Evidence / boundary |
| --- | --- |
| Battery hardware, charge protection, automatic power profiles, calibration and sleep | `bar-daemon/src/battery/{config,policy,levels,monitor,helper}.rs`, `src/api/battery.rs` and power/sleep modules own validation, persistence and effects. QML's slider constraints and pending drafts are supplemental UI behavior. |
| Application catalog, process telemetry, attribution and stored history | `app-daemon/src/history.rs` and `src/history/aggregate.rs` own collection, retention, duration-weighted buckets and cursor epochs. Remaining frontend window statistics are listed below. |
| Bluetooth discovery, pairing, reconnect/noise-control policy and persistent device state | `bt-daemon` owns BlueZ/device operations. Prompt order, draft retention, selected adapter and icon ordering legitimately remain in QML. |
| Clipboard data, revision-checked mutations, edits, screenshot/annotation effects | `clip-daemon/src/actions.rs` and `src/ringboard.rs` own the backend operations, leases and revision checks. History snapshot consumption and QR-related frontend artifacts need separate attention. |
| NetworkManager operations, saved-profile version checks, QR intake/credential validation and health classification | `nm-daemon/src/daemon_qr.rs`, `src/qr.rs`, profile handlers and `src/nm/health.rs`. The UI must not reclassify raw NM states. |
| Notification ingestion, expiry, DND, snooze and history | `bar-daemon/src/activity/notifications/engine.rs` owns time-based behavior and persistence. Group expansion, reply drafts, calendar selection and toast placement remain UI work. |
| Shared transport | `daemon-framework` now carries per-request addresses with tasks and stores live subscription routes in Rust. QML's small view-intent state is not the authority for domain operations. |

## Remaining migrations, in priority order

The [implementation plan](proposals/frontend-domain-migration.md) defines delivery
phases, daemon contracts, removal targets, tests and coordinated rollout.

### 1. Secret-bearing Wi-Fi QR artifacts → nm-daemon

**Implemented after audit:** native in-memory SVG rendering, metadata-only
availability, explicit credential fetch, profile-version fencing and dialog
reply-generation checks. Removed the frontend QR subprocess/file cleanup and
password parser. The evidence/target below records the original finding.

**Evidence:** `wifi/process/WifiQrService.qml` invokes `qrencode`, writes SVGs at
`$XDG_RUNTIME_DIR/shelllist-wifi-qr-<generation>.svg`, and invokes `rm` on close.
It also reparses the daemon-generated payload to recover the password.
`wifi/ShareAvailabilityController.qml` caches complete credential-bearing payloads
while checking whether sharing is available.

The current code correctly refuses shared `/tmp` and keeps secrets off argv.
Nevertheless, cleanup still depends on the UI surviving, filenames reset with a
new frontend instance, and renderer completion refers to mutable current state.
These are avoidable artifact/lifetime risks; this audit did not demonstrate an
external credential disclosure.

**Target:** explicit share requests should return an in-memory QR image and the
explicitly requested display fields from `nm-daemon`; availability checks should
not populate a long-lived frontend credential cache. If a file is unavoidable,
use daemon-owned private, unique, caller-scoped leases with expiry/cleanup.
Launching an interactive scanner/browser and rendering the returned image remain
UI responsibilities.

**Acceptance:** no frontend QR subprocess/file cleanup or password reparsing;
close/reopen, overlapping requests, UI crash and daemon restart cannot display
another request's image or leave unbounded artifacts. Secrets never appear in
argv/logs and are not returned by availability-only requests.

### 2. Clipboard history snapshot/cursor ownership → clip-daemon

**Implemented after audit:** native catalog search and revision-bound opaque
cursors; changes invalidate cursors rather than retaining snapshot leases. QML
loads only requested visible pages and does not reconstruct a search catalog.
The original literal/offset API remains for legacy clients, not new QML. The
following evidence/target records the original finding.

**Evidence:** `clipboard/ClipboardController.qml::applyHistory` concatenates pages,
requests the next page using its local accumulated length, and replaces
`historyRevision` on each page without requiring a single revision throughout.
`clip-daemon/src/ringboard.rs::finalize_query` returns each query's revision and
`next_offset`; queries are projections of the current store, not a leased
multi-page snapshot.

Changing history between offset-based pages can duplicate or omit rows. Moving
request routing to Rust does not resolve this data-consistency problem. Merely
moving `concat` into Rust would not resolve it either.

**Target:** daemon-owned revision-bound cursors/snapshots, explicit stale-cursor
errors, bounded pages, and daemon-side query/index ownership where appropriate.
QML may request more visible rows and reconcile delegates, but should not
reconstruct an authoritative catalog by fetching up to 5,000 mutable entries.

**Acceptance:** insert/delete/reorder between page requests, concurrent consumers,
non-advancing cursors, cancellation and restart cannot silently yield a mixed
snapshot. Keep stale mutation/revision rejection in the daemon.

### 3. Battery history energy and forecast semantics → bar-daemon

**Implemented after audit:** cached native Wh bins/coverage and typed forecast
status/target/ETA, with explicit aggregate scope and power measurement validity.
Removed the JS energy and forecast implementations. The following records the
original finding.

**Evidence:** `battery/BatteryHistory.js` still defines discharge eligibility,
trapezoidal Wh integration, observed-time bins, target-charge ETA scaling and
maximum acceptable charge estimates. `bar-daemon/src/battery/history.rs` already
owns samples, operating modes, observation continuity and retention.

**Target:** return bounded energy bins/totals, observed duration and a typed
forecast with validity/target/limit information. Retain sample-to-pixel mapping,
shared hover, line/fill painting and duration formatting in QML. Do not replace
this with daemon-supplied pixel coordinates or keep a JS calculation fallback.

**Acceptance:** move the current energy/forecast policy tests to Rust and cover
sleep/restart gaps, mode transitions, invalid samples, zero/full charge and
protection limits. Fixtures must distinguish missing measurement from zero.

### 4. Hyprland state parsing and workspace-rule resolution → native adapter

**Evidence:** `qml/Shelllist/Io/process/HyprlandWorkAreaClient.qml` repeatedly runs
`hyprctl --batch -j` while open. `HyprlandWorkArea.js` parses concatenated JSON;
`HyprlandWorkspaceRules.js` interprets selectors and window counts. This is a
second compositor-state parser inside the QML engine.

**Target:** extend the typed `shelllist-hyprland` Rust adapter and expose cached,
monitor-keyed work-area insets through a subscription, naturally via the existing
bar daemon. Keep QScreen's logical size authoritative in QML, along with final
pixel clamping, placement and view-specific layer rules.

**Acceptance:** fractional scaling, special workspaces, monitor changes, workspace
selectors, runtime gap changes and malformed/offline compositor data preserve
current layout behavior. No frontend JSON-document splitting or rule grammar.

### 5. Resource-window statistics → app-daemon

**Evidence:** `launcher/ApplicationResourceHistory.qml` and
`ApplicationResourceLaneChart.qml` repeatedly calculate mean/peak/availability
across history in bindings and paint callbacks. Means are computed per record,
whereas the daemon already retains `duration_ms` and duration-weighted buckets.

**Target:** an authoritative selected-window summary with per-metric observed
coverage, mean semantics, peaks and validity. Keep visual scaling, guide lines,
colors and paint paths in QML. Do not assume every record represents equal
observed time; define whether each mean is sample- or duration-weighted once in
the daemon.

**Acceptance:** mixed-duration buckets, missing capabilities, retained app history,
and window changes produce consistent labels/reference lines without duplicate
statistical implementations.

### 6. Astronomical estimates → bar-daemon (lower priority)

`activity/WeatherVisuals.js::moonPhase` derives lunar phase/illumination from an
epoch and fixed period. `TimeWeatherTimePane.qml` estimates solar noon from the
midpoint of sunrise/sunset. These are data estimates rather than pixel geometry.
Move their values and approximation/availability semantics to the activity/weather
payload. Keep moon masking, sun-arc progress and localized labels in QML.

## Corrections made in this audit

- `wifi/NetworkHealth.js::isFailure` now consumes only the daemon's explicit
  boolean `notification_recommended`. Removed the second terminal-state/reason
  classifier and legacy `unexpected` inference. Status-line deduplication and
  readable fallback text remain UI presentation.
- Regression tests cover future daemon-classified states and missing/malformed
  recommendations as well as quiet successful/lifecycle transitions.
- `tests/check-sibling-boundary.sh` now checks the candidate `daemon-framework`,
  verifies app-daemon's vendored framework matches it, and avoids writing release
  locks while testing. Previously it could validate candidates against an older
  bridge and miss a coordinated-deployment mismatch.
- Updated boundary guidance so it does not describe domain policy as belonging
  in frontend controllers or in the generic bridge.

## Verification of this audit's changes

- Network-health JS regression checks and shared-daemon boundary checks passed.
- Full QML suite: 194 passed; nm-daemon health tests: 5 passed.
- Sibling-gate shell syntax, current vendored-source equality and command wiring
  were checked. Wiring used a mock Nix executable to verify candidate overrides
  and non-writing lock flags; the full Nix package/flake matrix was **not** run.
- No deployed services or release pins were changed.

## Release/verification contract

For each migration: implement and test daemon semantics first, update its owned
fixture, consume the new fields in QML, remove the superseded JS policy, and run
both daemon and QML tests. UI hiding/crashing must not change authoritative
results. Never replay an uncertain mutation during reconnection.

Run `tests/check-sibling-boundary.sh` before advancing release pins. The latest
routing fix still requires matching rebuilt client binaries and QML; local
commits alone do not deploy it. Only migrations explicitly marked implemented above are complete. A passing
fixture or source audit must not be described as proof that pending ownership
problems have been fixed.
