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

## Version provenance and configuration locks

The managed tool's installed/latest comparison describes that installation only.
An up-to-date vendor profile does not erase an older generation package. The
update-owned overview joins generation inventory to tools by `vendor_tool` and
reports `fallbacks` separately; unavailable inventory remains unknown. Shelllist
shows these versions alongside the comparison, and the shared software inventory
shows differing active and declared versions together. Neither observation proves
which executable a particular startup entry or running process selected.

The optional `inputs` overview is a bounded, read-only observation of the current
configuration lock and existing queue. Direct remote root inputs expose their
reference, locked revision, revision date and configured update policy. Policies
distinguish delayed updates, refresh at candidate build, manual inputs and an
explicit source revision. A routine lock is not a user-requested hold. Local
worktrees and follows aliases do not introduce independent remote pins here.
Revision dates are not installation/pinning dates; configured locks are not proof
of active deployment or knowledge of the newest upstream revision.

Queue timestamps expose first observation and the end of the configured delay,
plus a nullable match against the observed configuration revision/base lock. The
deadline does not imply readiness, automatic installation or satisfied approval.
An invalid baseline's existing reasons appear in the Now/System summary, without
changing the approval guard. Missing older-backend fields remain unknown; malformed
replies retain the last accepted snapshot. Labels and facts add no editable stops.

See `tests/update-version-provenance.md` for executed coverage and deployment limits.
