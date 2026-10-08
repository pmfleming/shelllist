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
Full native library suite and Qt suite: 315 passed, one existing RHI skip.

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
