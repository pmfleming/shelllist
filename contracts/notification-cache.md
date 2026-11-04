# Notification working-set contract

`NotificationCatalog` and `NotificationTimeline` each retain at most 200 published
rows and 200 separately staged rows. Native app groups, period membership,
ordering, grouping and counts remain authoritative. A short byte-limited page
reserves room for the next full native page (50 apps / 20 timeline rows), so the
working-set boundary may be slightly below 200. No row is silently truncated.

Automatic scrolling stops at that boundary. Explicit **More applications
(Alt+M)** or **Load older notifications (Alt+L)** replaces the bounded window.
**Latest applications (Alt+F)** and **Latest notifications in period (Alt+B)**
return to one first page without changing the query or chosen period. Window
replacement resets the viewport rather than using an old bottom-of-list anchor
to automatically refill the previous range. Ordinary append/refresh retains
keyed viewport anchoring.

Refresh starts at the current window's native offset with its issued
revision/epoch/period scope. Anchor refill stops at the cache bound even when an
old tail disappeared. A stale cursor restarts once at the first page; repeated
staleness or malformed/error responses retain the last accepted window without
an automatic retry loop. Replacement rows, offsets and scope publish together;
late generations and responses received while inactive are rejected.

The app reader retains unpublished rows, epoch and revision in one staging
record. Validation consumes that record once; only a valid continuation installs
another complete value. Failure, stale reads, publication and deactivation leave
no staged cursor behind. Explicit exact-app scans may discard their bounded row
prefix while retaining the accepted cursor for the next page. Published arrays
remain unchanged until the complete replacement is accepted.

An explicit exact-app/group route may scan farther than 200 app groups, but only
one bounded staged window is retained while scanning. It owns a new read
generation even if a normal read is in flight. Missing resolved targets are
reported rather than indefinitely retaining a pending route.

Inactive readers release rows, snapshots, cursors, anchors and staged reads.
Panel close also releases provider rows, pending routes and per-app presentation
metadata; that metadata is capped at 64 app/query keys while active. Reopening
reads one first page, never the previously browsed prefix. Shared live
notification state, preferences and deletion/confirmation ownership are not
cleared or reinterpreted by this presentation-cache policy.

## Daemon restart and relational storage v2

Daemon disconnection is a session boundary, including the v1-to-v2 storage
cutover. Clear published/staged catalog and timeline rows, old offsets/epochs,
live records/toast decks, pending operation ownership and deletion tokens.
Invalidate late completions before accepting the new daemon's snapshots. Reset
the revision floors so revision zero and an empty history page are authoritative.
Do not replay settings, actions or deletion requests against the new daemon.
Unsent reply text is retained under the complete record identity and is never
sent automatically. Panel close within one session still follows the cache policy
above; it does not reset shared live state or acknowledged preferences.

The paired daemon now owns `notifications-turso-v2.db` with typed content,
ordered actions, previews and preferences. It ignores both older default files,
`notifications.sqlite3` and `notifications-turso-v1.db`, without deleting them.
Saved history, DND/settings, app policies, ID counters and once-only delivery keys
start fresh; previously delivered events may arrive again. Subsequent v2 starts
retain the new data, with old conversations becoming closed history. The API
remains unchanged and QML never reads the database or migrates old saved records.

Build/deploy both repositories using the existing shared local-workspace build
workflow; the flake resolves current sibling sources and must not acquire a new
local revision pin. Reboot or restart the daemon and Shelllist after deployment.
An exact `BAR_DAEMON_NOTIFICATION_DATABASE` override must point to a nonexistent
file in a private directory, rather than an older store. No operator preparation
is needed for the default path. Source qualification does not deploy services.

`tst_notifications.qml` covers stale-token retirement, immediate cache/live-state
release, retained unsent text, ignored late reads, lower revision acceptance,
empty v2 history and subsequent notification delivery. Daemon Rust tests own
storage creation, incompatible-store rejection, restart and crash persistence.

`tests/qml/tst_notification_cache.qml` exercises all 805 synthetic rows in both
readers, bounded/short/malformed pages, older-window refresh, exact lookup during
an in-flight read, atomic error retention, one-shot stale recovery, inactive/late
replies, cache release, native Alt commands and viewport reset. Existing
notification suites continue to own settings, deletion tokens and record command
identity/acknowledgement tests. These are recording-transport Qt tests, not live
destructive operations or network-latency benchmarks.
