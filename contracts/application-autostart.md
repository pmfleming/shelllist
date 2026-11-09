# Application autostart

Applications → Settings exposes **Autostart** after **Open on a new workspace**,
using the shared `ToggleRow`/`FieldRow` composition. It is one editable stop for
desktop applications with a known boolean `autostart` observation. Unknown or
older-backend values leave it unavailable; windows and shortcuts have no switch.
Labels and explanatory feedback remain passive.

Tab and Shift+Tab browse without changing it; Enter or a pointer click submits
one `{target_id, autostart}` patch through `applications.settings.update`.
Pending settings disable conflicting switches. The value stays bound to the
native catalog, with no optimistic update or automatic mutation retry. A failed
request retains the acknowledged value and uses shared surface feedback; an
explicit toggle retries. Stale acknowledgements cannot retire newer requests.
Category errors remain scoped to the category field.

`app-daemon` owns XDG autostart files, with user configuration taking precedence
over same-named entries in the system configuration directories. The desktop ID
is the filename; differently named entries and other startup mechanisms are
outside this setting. Enabling creates a user entry from the installed launcher,
or updates an existing entry. Disabling writes a user `Hidden=true` override so
a system entry cannot become active again through deletion. Existing launch
arguments, desktop conditions, actions, working directory and terminal settings
are retained. Minimal disabled masks recover launch metadata from the installed
desktop entry when re-enabled. GNOME's enable flag follows the requested state.
Symlinked/declaratively managed user entries are not replaced.

The file is written atomically before acknowledgement. Autostart is not duplicated
in the preferences database. Catalog revisions include its observed state;
configuration-directory watches and periodic reconciliation notice external edits.
Unreadable/malformed state is unavailable rather than silently off. Autostart
patches cannot be mixed with database-backed workspace preference updates.

The setting configures the next desktop login; changing it neither launches nor
closes an application, and restarting Shelllist does not launch applications.
The session must process XDG autostart entries. Desktop conditions such as
`OnlyShowIn`, `NotShowIn` and `TryExec` still apply. Workspace routing preferences
apply to Shelllist launches, independently of session-owned autostart launches.

Native behavior follows the [XDG autostart specification](https://specifications.freedesktop.org/autostart/latest/).
Evidence owners: `tests/qml/tst_application_settings.qml` (real Qt key/pointer,
pending/failure/retry and acknowledgement), `tests/test-native-application.py`
with `tests/e2e/application.qml` (Qt → daemon → file), and sibling
`app-daemon/src/autostart.rs` tests (file persistence, precedence, preservation,
minimal masks, invalid identities and protected files).
