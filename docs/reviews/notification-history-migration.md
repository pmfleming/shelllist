# Notification history: native ownership

## Regression and resolution

The batching regression was reproduced with real Qt objects: a persisted
notification becomes transient and closes before the queued active-state flush.
The overwritten intermediate snapshot hid its deletion, and the frontend's
retired/history union retained the old content even after an empty daemon read.
A targeted invalidation fix passed first. The end-to-end migration removes the
underlying alternate catalog instead: no retired-record cache, active/history
union, JS search, history-ID merging or frontend ordering remains.

`bar-daemon` owns the `notifications.queryHistory` catalog. Shelllist retains
only requested visible records, staging of an atomic replacement window, query
intent, selection/viewport, local reply drafts and pending command feedback.
Active snapshots still drive toasts and current action capability guards; they
cannot resurrect center history. The original `notifications.list` remains for
legacy clients, not this frontend.

## Contract

- Search: Unicode-lowercase literal substring over app name, summary and body;
  newest 5,000 persisted records plus at most 200 unsnoozed live records. No
  retention deletion is introduced. Query limit is 1,024 UTF-8 bytes.
- Pages: default 50, maximum 100 records, 512 KiB serialized record-content
  budget, two concurrent native readers. An oversized individual record fails
  visibly. SQL sorts bounded candidate IDs, not the full payload catalog.
- Identity/order/deduplication: native `(created_unix_ms, id)` descending;
  live records override their persisted identity. Closed/transient replacements
  are absent after a fresh query, even when all intermediate events were missed.
- Cursors: opaque read positions, daemon epoch, exact string revision and query;
  120-second expiry, no retained leases or caller-owned mutations. Native reads
  hold the mutation/persistence-enqueue boundary. A persistence write failure
  makes catalog reads fail closed for the worker lifetime.
- Refresh: the client sends its oldest visible record position. Native pages
  say when that anchor has been reached or passed, including deletion. The
  client stages those pages and atomically replaces its visible window; append
  accepts only the same epoch/revision. It never merges old records into a new
  snapshot. Old same-query results remain visible until replacement is ready.
- Recovery: query/transport generations fence late replies; stale cursors retry
  reads only. Ordinary bounded read RPCs may finish after supersession; they are
  not passed to the daemon's subscription cancellation API. Empty, malformed, duplicate and non-advancing pages cannot loop or
  silently mix revisions. Unknown APIs fail visibly without a policy fallback.

The normal chooser key model is unchanged. Search also pages while filtered.
Stable model identities retain viewport, selection and live reply transactions
across replacements; search changes do not discard saved identity-owned drafts.

## Validation

- The original batching regression passed after the targeted fix and remains
  covered through the authoritative query response after migration.
- Qt notification tests cover actual search keys, superseded replies, native
  cursors, stale/restarted epochs, non-progress, atomic refresh, deletion,
  viewport prepend/append and reply focus/drafts.
- Native tests cover SQLite migration and Unicode search beyond the first page,
  literal wildcard characters, bounded search scope, byte-limited progress,
  independent pages, legacy rollback/re-upgrade search-index repair,
  replacement/closure/restart invalidation, deletion without
  intermediate reads, deleted refresh anchors, read-admission cancellation and
  failed persistence. Existing mutation/signal-ordering tests remain intact.
- Full local offscreen Qt run: **285 passed, zero failed** (Qt 6.11.1 with
  matching SVG plugins). Native all-target tests: **160 library tests and one
  integration test passed**, with two existing opt-in tests ignored. Rustfmt,
  all-target Clippy with denied warnings, changed-component warning-fatal QML
  lint, presentation/boundary JS checks and compiled wire-contract checks pass.
- The **final captured sibling Nix matrix passed**, including all five daemon
  packages/contracts, the shared framework, frontend packaging/module evaluation,
  TypeScript freshness and sandboxed QML/lint checks. The passing sandboxed Qt
  total is also **285**. Early overlapping builds exposed focus/incubation timing
  failures in chooser memory and two notification tests; the subsequent captured
  run and final matrix passed without disabling tests or changing timeouts.
- Evidence: `/tmp/notification-history-family-release.log`,
  `/tmp/notification-history-sandbox-qt.log`, `/tmp/notification-history-full-qt.log`,
  `/tmp/bar-history-all-tests.log`, and `/tmp/bar-history-clippy.log`.
  The final cursor-escaping bound regression is included in the native package
  verified by the final matrix. No live compositor or notification-history
  mutation acceptance was performed.

## Rollout

The API/storage changes are additive. Build the daemon and Shelllist from the
same current sibling-worktree graph using `tests/check-sibling-boundary.sh` /
`daemon-framework/tools/local-build.py`; local daemon revisions are not selected
from historical release-lock entries. No services are activated by this work.
The pre-existing unrelated `flake.nix` display-test import change is preserved
and excluded from the implementation commit.
