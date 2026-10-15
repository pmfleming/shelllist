# Daemon ownership reconciliation

The October 8 opportunity review is historical, not a list of migrations still
missing from the current tree. During the packaging/ownership rollout the
following native implementations and frontend consumers were inspected:

| Concern | Native authority | Current UI boundary |
| --- | --- | --- |
| Calendar-day membership | bar-daemon `src/activity/day.rs` (timezone-aware ranges/day projection; DST tests) | Activity consumes day IDs; `ActivityFlow.js` only formats dates and selects local midnight |
| Bluetooth apply-and-remember | bt-daemon `src/daemon/audio.rs` (one device gate retained by the worker; applied/persisted outcomes) | Submitted profile request includes remember intent; no separate persistence write |
| Display stale edits | bar-daemon `src/display_policy/layout.rs` (process-scoped keyed baseline, rechecked against fresh outputs before preview) | Draft captures/sends opaque baseline; local stale indicators remain supplemental UI feedback |
| Resource totals/confidence/availability | app-daemon `src/history/summary.rs` and resource projections | TS reads observed_total/total_unit, energy_confidence and metric_availability; it does not recompute domain totals |
| Close observation | app-daemon `src/service/action/close.rs` (captured addresses/PIDs, bounded observation, closed/still-open/unknown outcomes) | ApplicationOperations consumes targeted_window_ids and close status rather than inferring closure from filtered results |
| Commit and prepare paste | clip-daemon `src/actions.rs` (single-use edit lease, publication check and session-bound arming) | UI submits paste_session_id and retains the explicit hidden/focus handshake; uncertain edits/pastes are not replayed |
| Hidden-network/recovery forms | nm-daemon prompt descriptors | WifiPromptPolicy consumes security_modes; Wi-Fi errors do not initiate a second credential transaction |
| Time/weather identity | bar-daemon `src/activity/locations.rs` | TimeWeatherController consumes activity.locations; sorting/filtering/selection remain presentation |

These implementations were already present at the rollout baseline. Do not move
UI drafts, chart geometry, field validation feedback, focus handling, revision
fences or explicit browser/scanner placement into daemons merely to reduce QML.
Single-field Bluetooth adapter saves remain legitimate UI intent; inventing a
batch API would not establish atomic BlueZ semantics.

The actual missing ownership was deployment: Shelllist bundled bar-daemon and
configured backend units, privilege metadata and policy options. Those now belong
to independent daemon modules; see [deployment migration](../daemon-packaging.md).
The display-unavailable hint and current installation/media/display documentation
now name the daemon-owned options. A Qt regression checks the hint without
issuing a mutation or making unavailable display policy actionable.

Validation is recorded in `/etc/nixos/docs/daemon-ownership-rollout.md`; source
inspection does not substitute for the full consumer contract/Qt/daemon gate or
live deployment acceptance. No keyboard model, numeric UI styling, hardware
operation semantics or permission policy was changed in this reconciliation.
