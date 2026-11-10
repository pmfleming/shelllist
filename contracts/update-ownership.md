# Update domain owner

update-daemon owns update execution, observation, history, incidents, release
comparison and notification policy. Its shelllist-update-status crate owns the
read API. See ../../update-daemon/contracts/ownership.md for migration stages.

Shelllist retains rendering, translations, navigation, request lifetime guards,
wire validation, settings drafts and the 200-run history window. Read/refresh
never runs an update. bar-daemon compatibility routing must only forward the
update-owned API, without reading update state files or database tables.

Existing chooser keyboard, shared UI and update-history-cache contracts remain
authoritative. Backend relocation must preserve actual Qt interaction behavior.
