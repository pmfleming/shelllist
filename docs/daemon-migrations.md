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
