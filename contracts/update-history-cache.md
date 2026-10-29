# Bounded Updates history cache

This supersedes the older unbounded loaded-prefix presentation described in the
local Updates reference. Producer retention remains unchanged: the panel never
deletes history files, changes incident recovery evidence or executes an update.

## Lifetime and size

- `UpdateHistoryWindow.maximumEntries` caps each published and staged history
  window at **200 runs**. The old published window remains available while its
  bounded replacement is read. The pinned Now result is additional, not a run.
- Closing Updates retires its staged request, drops published entries and provider
  result metadata, and clears cursors, revision, anchors and folded-group IDs.
  Late replies cannot repopulate either a closed or subsequently reopened view.
- Reopening reads one recent page (normally 50 runs) for the retained search and
  filters, not the previously browsed depth. An explicit exact-run route still
  reads its named run and opens that run's inspector.
- Existing request deadlines, per-page wire validation, duplicate rejection and
  the 128-page continuation guard remain. Oversized staging is rejected before
  concatenation. Requests shrink their page limit to the remaining cache space.

## Paging and keyboard behavior

Near-end loading appends within the 200-run window. At the cap, automatic loading
stops; it cannot silently evict the inspected run. The existing Alt+L command
becomes **Load older updates**, explicitly replacing the window with the next
page after a successful read. Subsequent loads append within that new window.
All retained backend history remains reachable, without keeping earlier windows.
Counts show the absolute matching range when browsing older history.

**Latest updates (Alt+B)** returns to one recent page without clearing search,
lane or outcome. Existing **Show all recent updates (Alt+A)** additionally clears
those filters and exact-run context. Both use the shared command registry, not
editable Tab stops. The footer retains shared typography, spacing and controls.
An evicted selected result closes its inspector rather than displaying another
run under the old selection. Surviving results keep the existing keyed selection
and viewport behavior.

## Refresh and cursor ownership

- Recent-window refresh preserves its loaded range and selected/tail anchors
  only up to the cap. A displaced tail cannot force replay of hundreds of old
  records. The next cursor still addresses the first record not published;
  reaching the cap must not skip history.
- Older-window refresh starts at its original **backend-issued cursor**, with
  the original anchor parameters that contributed to that cursor's revision.
  It reads at most the bounded current window, not the prefix before it.
- A stale older cursor gets one restart at the latest page, without old anchors
  or old depth targets. Successful recovery reports “History changed; showing
  latest updates”. Failed recovery preserves the last good window and error.
  Another stale reply cannot start an unbounded retry loop.
- Offset-aware validation compares the absolute end with the reported total;
  revisions, continuation metadata and duplicate identities remain fenced.
  The frontend neither parses nor manufactures backend cursor tokens.
- Filter/query changes and exact-run links start from their own query, never
  from another window's cursor. No daemon protocol change is required.

## Regression evidence

`tests/qml/tst_updates.qml` includes actual native Alt+L / Alt+B navigation across
805 records with a 200-run bound, all older records reachable, direct older-window
refresh, closure during a staged refresh, late replies after reopen, bounded
anchor refill, failed replacement, oversized replies, stale older recovery,
filter preservation and exact-run independence. Existing keyboard transactions,
logs, invalid-history retention and selected/viewport preservation remain covered.

Run in the Qt development environment:

```sh
tests/run-qmlquality-tests.sh -input tests/qml/tst_updates.qml
```

Validation on 2026-10-29:

- Updates suite on deployed-version Qt 6.11.1: **47 passed**.
- Complete Qt 6.11.2 suite: **676 passed, 0 failed**, one existing RHI-only
  artwork skip. Counts include lifecycle hooks.
- Strict lint of changed production QML: pass; panel role review: zero prompts.
- Light/dark normal/minimum Update capture fixture: **6 passed**.

Local logs are ignored under `target/update-history-cache/`. No producer files,
live updater state or services are modified by the fixtures. No live deployment
or restart was performed.
