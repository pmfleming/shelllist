# Daemon migrations — implementation ledger

Each migration has separate owning-daemon and Shelllist commits. Existing dirty
work and staged documentation removals are excluded. No running services are
restarted; matching daemon/frontend deployment is required.

## Calendar day projection

`bar-daemon` publishes date-keyed event/todo identities and a local-date basis
from timezone-aware dates, shared with busy-day markers. Shelllist retains only
calendar selection and presentation; timezone events and local-midnight detection
refresh the projection. No draft, command or field-transaction policy changes.

Validation: native activity tests (including 23/25-hour days and exclusive
all-day ends), and Qt pointer/Enter day commands consuming native membership.
Native library suite passed. At this stage the Qt suite had 315 passes and one
existing RHI skip.

## Bluetooth apply-and-remember

`bluetooth.audio.setProfile` accepts optional `remember`. The device gate stays
held across hardware application and durable policy persistence, including when
the caller disconnects after the blocking operation starts. `profile_outcome`
distinguishes applied/remembered from applied/persistence-failed, even if the
subsequent audio snapshot cannot be refreshed. No implicit replay or rollback is
claimed. Shelllist sends one captured device/profile request and renders its
outcome; it no longer chains a separate policy write.

Validation: native partial-outcome/parameter tests and Qt profile recovery tests.

## Native display baseline checks

Display snapshots include a process-scoped opaque baseline over policy,
identities, geometry, mirroring and mode catalogs. Preview requires this token
and compares it with freshly observed compositor state under the shared policy
write lock, before writing a durable trial or changing outputs. Confirmation and
rollback keep their original token, eligibility and timeout guards. Frontend
fingerprints remain conservative early hints; they are no longer the sole guard.

Validation: stale previews make zero writes; catalog/policy changes invalidate
tokens, mode ordering/focus do not. Native rollback/mirroring tests and Qt display
interaction tests remain in the gate. Deploy the daemon and consumer together.

## Resource projection

`app-daemon` publishes `metric_availability`, summary `observed_total`/`total_unit`
and full-window `energy_confidence`. Totals use only clipped observed durations;
unavailable intervals and non-RAPL energy are excluded. History pages share the
same canonical summary. Consumer checks retain window identity, units, finite
values and missing-metadata rejection; formatting and graph geometry remain local.

The native resource fixture is regenerated with
`APP_DAEMON_UPDATE_RESOURCE_FIXTURE=1 cargo test --lib resource_projection_fixture_is_current`
and copied into Shelllist. Tests cover zero, unavailable capabilities, confidence,
clipped energy totals and Qt range-field transactions/read-only card traversal.

## Observed application Close

The operation captures actual compositor window IDs and process identities before
close dispatch. Owned running/status results retain targeted and dispatched IDs;
a bounded observation reports remaining IDs and closed/still-open/unknown.
Dispatch failures preserve partial outcomes. Cancellation stops observation, not
already-dispatched compositor requests. New/unrelated windows do not prevent
confirmation. Shelllist no longer infers closure from filtered/paginated results
or polls those results to manufacture completion.

Validation: native disappeared/replaced/still-open/unavailable/dispatch-failure
cases and cancellation retention; real Qt row commands, native outcome rendering
and focus recovery. No automatic replay and no live compositor acceptance run.

## Clipboard commit-and-prepare

Edit commit accepts optional `paste_session_id`, validates it before mutation,
consumes its edit lease once, and arms it only after successful publication.
The response separates saved entry/publication from paste preparation. Input
injection remains exclusively behind the existing session-hidden handshake.
Late replies cannot hide/paste into a reopened session; publication failure does
not cause a second commit or publication. A separately requested Paste arriving
after an ordinary save was already submitted retains its existing post-save
request path (not a replay of the edit).

Validation: native publication failure, stale session, lease consumption and
revision-conflict tests; actual Qt Enter/Paste with success, partial failure and
reopened-session cases. No live focus/input-injection test was run.

## Canonical time/weather locations

Activity snapshots now carry native location records. Stable weather IDs and
index-independent local/clock IDs survive ordering changes; duplicate clocks
resolve deterministically, while distinct weather places sharing a timezone are
preserved. Timezone events refresh the projection without another weather fetch.
The frontend retains locale sorting/filtering and restores selection by native ID.

Validation: native duplicate/order/same-timezone tests, a generated native fixture,
and actual Qt list browsing/detail entry with reorder-safe selection.

## Hidden-network and recovery descriptors

nm-daemon status publishes hidden-network fields, defaults, supported security
choices, key-management/WEP mappings and conditional requirements. Connection
failures publish credential-recovery prompts (including early failure events).
Shelllist retains generic descriptor rendering/validation, localization and
request encoding, but removes its hidden-mode mapping tables and reason-based
recovery policy. Existing native target/credential validation is unchanged.

Validation: native descriptor policy and contract tests; Qt missing-descriptor,
conditional requirements, F6/Escape, and native-only recovery prompt coverage.

## Commits and final validation

| Migration | Owning daemon commit | Shelllist commit |
| --- | --- | --- |
| Calendar days | bar `b7f04f3` | `7b85c58` |
| Audio apply-and-remember | bt `cfe37d1` | `54599c9` |
| Display baselines | bar `efa406a` | `6bac648` |
| Resource projection | app `3b25e89` | `009b35b` |
| Close observation | app `41901d0` | `223b514` |
| Commit-and-prepare-paste | clip `fa5ef3c` | `8eeac19` |
| Canonical locations | bar `1f663ee` | `f08ca09` |
| Wi-Fi descriptors | nm `a38dfbe` | `f042f7e` |

Test follow-ups: `7b77bd2` waits for calendar expansion before pointer input;
`a9e5d99` updates chart-geometry fixtures to native availability flags.

Final local working-tree validation:

- Qt: **322 passed, 0 failed, 1 existing RHI-only skip**.
- Native libraries: bar 227 passed/1 ignored; bt 66 passed; app 64 passed;
  clip 42 passed; nm 154 passed/3 ignored. Additional app/clip integration tests
  passed (14 and 7 respectively); three app manual tests remain ignored.
- Freshly built binaries passed all five daemon/consumer fixture and registry
  checks, including the separate app-resource fixture comparison.
- QML lint, runtime smoke, TypeScript generated-output checks, source-tree import
  resolution, daemon boundaries, chart intervals/availability, application
  history/lifecycle, Bluetooth lifecycle and display-model checks passed.
- Incoming Git indexes were compared byte-for-byte with saved index patches:
  unchanged in all six repositories, including 76 staged Shelllist paths.

Local logs and initial-worktree snapshots are under
`/tmp/shelllist-daemon-migrations/` (ephemeral, not release artifacts). Native
changes are committed separately from unrelated work; existing Shelllist and
nm-daemon changes remain outside these commits.

The separately conditional **adapter-setting batch API was not implemented**.
The review marked it "only if needed"; the existing shared field-save model and
submitted adapter-setting sequence are unchanged. This is not claimed as a ninth
completed migration.

No services were restarted and no pins or deployment configuration were updated.
The full pinned/Nix release gate and live hardware/compositor/focus acceptance
remain unverified. Deploy matching daemon and frontend revisions together.
