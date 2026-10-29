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

`tests/qml/tst_notification_cache.qml` exercises all 805 synthetic rows in both
readers, bounded/short/malformed pages, older-window refresh, exact lookup during
an in-flight read, atomic error retention, one-shot stale recovery, inactive/late
replies, cache release, native Alt commands and viewport reset. Existing
notification suites continue to own settings, deletion tokens and record command
identity/acknowledgement tests. These are recording-transport Qt tests, not live
destructive operations or network-latency benchmarks.
