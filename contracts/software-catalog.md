# Shared software catalog

The launcher and Updates use the app-daemon-owned Turso catalog at
`$XDG_STATE_HOME/app-daemon/software-catalog-turso-v1.db` (default
`~/.local/state/app-daemon/`). This is a pristine schema: no settings JSON import,
SQLite conversion, automatic upgrade, unknown-file reset, or compatibility fallback.
Existing category overrides are intentionally not imported. Resource history remains
in its separate Turso database.

## Ownership and identity

- app-daemon is the sole database writer. Its API serves both views; consumers
  never open the database. Tables hold application records, preferences, snapshot
  metadata and the last worker observation. A transaction publishes related records
  together. Uncertain commit/rollback outcomes fence further access until restart.
- Desktop IDs are the launcher's existing exact IDs. Desktop names, icons and
  category defaults come from the desktop catalog. User overrides and new-workspace
  preferences live only in Turso; the existing category-to-workspace mapping remains.
- `update-worker application-status --json` is an unprivileged metadata-only read.
  It reports active-generation package declarations, cached releases and active
  managed-tool receipts. It runs no release check, package manager or installer.
- Nix inventory records add `store_path`, `desktop_ids`, `kind` and `vendor_tool`.
  Package-to-desktop joins use reviewed desktop IDs or the exact owning Nix store
  output, never display-name similarity. Unmatched desktop apps remain present
  with unknown versions. Unmatched packages remain separate catalog records.
- Each record retains all scoped installations and their declared version, active
  version, origin and release evidence. Active managed-tool versions take precedence
  for display without overwriting the generation's declaration. Different versions
  are shown together rather than choosing an arbitrary installation.
- Worker reads have a five-second deadline and a 2 MiB limit. Ordinary reads reuse
  observations for 60 seconds; explicit refresh rereads local evidence. Failed reads
  retain persisted observations, mark them stale, and expose the failure. A successful
  replacement removes packages that disappeared from the inventory. Existing worker
  coverage limits remain explicit (`inventory_included` / `inventory_total`).

## API and presentation

`applications.catalog` returns the full bounded catalog. `applications.query`
attaches the same persisted software record to each launcher result. Category
changes update preferences and catalog records together; caller cancellation cannot
interrupt the commit-to-memory publication. `applications.catalog.changed` invalidates
metadata consumers independently of resource sampling and window activity.

Updates reads the catalog directly from app-daemon. bar-daemon continues to own
update history and system/AI status; its raw package projection is not used for the
software list. Catalog responses are validated against the generated producer schema.
An invalidation during an in-flight read rejects that response and schedules a new
one. Closing the panel or losing transport retires its request identity.

The list orders desktop applications by category/name, then shortcuts, command-line
tools, system packages and local helpers. Every group has a heading and count; the
page shows the total software count. Package-only classifications come from reviewed
Nix metadata, with `system` as the explicit fallback. Updating a launcher's category
moves that app's Updates group through the same catalog publication.

Shared `DetailListView` shows a persistent draggable scrollbar when content overflows
and reserves a gutter in its consumers. It disappears when all content fits. It adds
no editable Tab stop. PageUp/PageDown, keyed viewport restoration, pooled-command
retirement and bounded delegate creation remain intact. The launcher and Updates
share version formatting and keep unsupported, unchecked, stale and failed evidence
distinct. A missing release source still cannot produce a latest version.

The launcher's Settings tab contains one **App data** card: local/latest versions
share a compact grid, installation facts use labeled shared FieldRows, and identified
storage sits above the persistent/temporary pair. The Application tab keeps window
and desktop-action collections. Shortcut and unmatched-window entries retain a
read-only Settings tab; category and launch preferences are shown only for desktop
applications. Metadata, storage values and Help add no editable Tab stops.

Package, Installed for, Release source and Last checked come directly from the
structured installation/release fields. Known GitHub latest-release API URLs
display as `GitHub · owner/repository`; other source strings remain intact.
The full source URL remains in the value's accessible description and the card's
disclosed details. Check times use local `d MMM yyyy, HH:mm` presentation, with
the full local timestamp in the accessible description. Missing source/check
values remain explicitly unconfigured/unchecked. Different active and declared
versions, cached observations and release errors retain separate labeled rows.
Multiple installations keep their own package, scope and version associations.
All values wrap in the existing label-left/value-right composition; none become
editors, links or additional keyboard stops. The UI owner uses zero spacing
between these shared rows because their built-in height/padding and separators
already provide the vertical rhythm; card group spacing remains theme-owned.

Storage availability and attribution are unchanged: a measured zero stays zero,
unknown stays unavailable, and a stopped app can use retained observations only
when the history target matches its ID. Opening Settings does not request history.

The launcher owns the App data composition: shared DetailColumnCard replaces
DetailCard to accommodate wrapped source details and grouped values, with shared
theme metrics and no custom editor or command identity. The panel UI review's
composition prompt is accepted for this passive layout.

Application Settings separates preference rows and App data groups using shared
theme spacing. Category and App data omit question-mark buttons; the workspace
switch omits persistent guidance below its label. Clicking those items discloses
their guidance in the existing status bar through one page-owned FeedbackSource.
New disclosures replace previous guidance; target changes and hiding the page
clear it. Operational errors retain higher priority. Shared FeedbackTapHandler
observes taps without taking editor focus or adding Tab stops; the switch also
discloses before dispatch, since pending requests disable its pointer area.

## Rollout and checks

Deploy app-daemon, update-worker, the Nix inventory module and Shelllist together,
then restart the user daemon/UI so the new schema and generated API agree. No
migration or rebuild is triggered by merely reading the catalog. The new database
is created on daemon startup; old JSON files are untouched and unused.
`APP_DAEMON_UPDATE_WORKER` can specify an absolute worker executable for packaging
or isolated tests; the default is `/run/current-system/sw/bin/update-worker`.

Backend tests cover exact joins, multiple installations, active versions, database
restart, exclusive ownership, unknown-file rejection, stale-cache retention,
transaction rollback and successful retry. Service tests compare launcher/API
records before and after category changes. Qt tests cover shared groups/version
formatting, response invalidation, late replies, scrollbar dragging, keyboard
scrolling, pooling and viewport restoration. The native application journey verifies
category persistence through the owner API after restarting the private daemon;
backend transaction tests own storage-failure injection.

`tst_application_settings.qml` verifies the combined App data card, narrow-width
metadata wrapping, compact sources/timestamps with full accessible provenance,
multiple installations and missing/failed checks, unchanged editable-field traversal, unavailable/zero readings,
target-scoped history and read-only entries. `tst_application_actions.qml` verifies
keyboard navigation to its single home in Settings.
The Settings suite also checks real label/editor/card/switch clicks, status-bar
disclosure, stable row geometry, absent help icons, error priority and clearing
context when the selected application changes.

Release-status filtering offers all eight domain states, including local builds,
unchecked and differing versions. Combined route/status filters must match one
installation, rather than borrowing a route from a different installation.
Storage cleanup history exposes skip counts and a shared information command;
the full reasons appear in the fixed visible feedback slot and accessible text.
