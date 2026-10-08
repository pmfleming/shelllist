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
