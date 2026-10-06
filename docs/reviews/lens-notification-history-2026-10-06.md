# Notification history maintenance — 2026-10-06

## Baseline and scope

This follows [bounded maintenance](lens-maintenance-2026-10-06.md). The baseline
is that **uncommitted working tree**, including the preserved concurrent media
changes, not bare `80056cc`. Its patch SHA256 is
`36759c196b6352721ad428f7f685a3d09e430a83e149b582d9f06e32c6e748d0`.

Only `activity/NotificationState.qml`, `activity/NotificationBackend.qml`,
`tests/qml/tst_notifications.qml` and documentation change in this step. Other
pending work is preserved. No keyboard model, daemon policy or transport protocol
changes; no generic state-machine framework or additional component is introduced.

## Responsibilities

- Backend completion consumes request ownership once, checks connection/query
  generations, flushes queued events, and then routes history separately from
  command acknowledgements. All requests already capture generation values at
  creation; missing-generation contexts no longer bypass those fences.
- `finishHistory` handles stale-cursor recovery, read errors and the observed
  history revision fence. History reads cannot complete reply/DND/operation state.
- `validHistoryPage` checks envelope shape and query identity. Epoch, revision
  and cursor share an explicit nonempty-string predicate; tokens remain opaque.
- `historyPageAdvances` checks bounded accumulation, forward cursor progress,
  valid record identities and duplicates before any visible publication.
- `applyHistory` retains revision/epoch consistency and atomic replacement.
  Only unfinished refresh pages are staged. A complete refresh replaces the old
  window rather than union-merging deleted rows; ordinary pagination appends.
- Query changes, disconnects and invalidation share the read-generation reset.
  Domain-specific behavior remains distinct: a query clears visible results,
  disconnect marks cached data unavailable, invalidation schedules a read-only
  refresh. Failed reads retain the visible window and discard staging.

## Regression evidence

Added 23 data-driven cases covering:

- Old-query success, ordinary failure and stale-cursor failure, each before or
  after the replacement request commits; duplicate completion is ignored.
- A queued revision change between refresh pages: stale staging cannot publish.
- Continuation read failure, loss of history-loading eligibility and epoch change:
  partial pages remain unpublished and no further continuation/mutation is sent.
- Missing/oversized/malformed pages, token types, query identity, anchor status,
  duplicate records and invalid notification identities.

Existing tests retain actual keyboard search and reply commands, acknowledgements,
reused record identities, connection fencing, visible-anchor refresh, selection,
viewport and live reply-editor retention.

The existing reply-command test intermittently failed before this refactor when
sending immediately after editor focus. It now waits for first rendering and
asserts typed text and saved draft before dispatch, without weakening any command
assertion. The final expanded suite passes against the frozen original production
files (**36 passes**) and on **five consecutive** refactored runs.

## Measurements

Local QML Quality Lens v0.5.0, commit
`c7e4d0bc7504ba11317927e87c2007a15616ad37`; same configuration and static comparison
method as the preceding review, including complete clone enumeration. No rules,
thresholds, suppressions or entrypoints changed. Helpers are included in totals;
this does not claim that splitting a function eliminates all its complexity.

| Function | Cyclomatic before → after | Cognitive before → after | Effort before → after |
| --- | ---: | ---: | ---: |
| `NotificationState.applyHistory` | 30 → 15 | 32 → 15 | 141 → 76 |
| `NotificationBackend.finish` | 25 → 17 | 31 → 20 | 128 → 90 |

| Aggregate | Production before → after | Including tests before → after |
| --- | ---: | ---: |
| Source lines | 37,578 → 37,587 | 45,498 → 45,616 |
| Cyclomatic sum | 7,332 → 7,329 | 7,938 → 7,952 |
| Cognitive sum | 4,917 → 4,905 | 5,164 → 5,163 |
| Function effort | 36,847 → 36,827 | 42,319 → 42,423 |
| Component effort | 41,458 → 41,447 | 50,497 → 50,611 |

**Tradeoff:** production grows nine source lines for clearer responsibilities;
regressions add 109 analyzed source lines. Total tracked code grows 121 physical
lines (56,656 → 56,777). This is not a LOC-reduction pass. Locality, leverage,
clone coverage and escape-hatch counts are unchanged. Overall Lens score stays 83.

## Validation and limits

- Full Qt suite: **286 passed, zero failures/skips**, directly and through Lens.
- Strict lint, runtime smoke and `git diff --check`: pass.
- Full Lens: zero verified/semantic failures; still **incomplete** on unresolved
  binding-side-effect targets, the existing tray-mock formatter error and partial
  coverage. Two existing parser disagreements and 109 formatting drifts remain.
- The full sibling-daemon Nix gate remains unverified after the preceding review's
  timeout; it was not rerun for this focused step. No deployment, live backend
  mutation, compositor or screen-reader acceptance is claimed.

Evidence lives under `target/lens-notification-history-2026-10-06/`: baseline
patch and production copies, worktree archive, frozen baseline with new
regressions, before/after snapshots and records, full Lens output, five focused
runs, baseline regression run, full-suite/lint/smoke logs. Reproduce with:

```sh
node target/lens-notification-history-2026-10-06/snapshot.mjs after
tests/run-qmlquality-tests.sh -input tests/qml/tst_notifications.qml -o -,txt
tests/run-qmllint.sh
tests/run-qml-tests.sh
tests/run-runtime-smoke.sh
node ../qmlqualitylens/dist/bin/qmlqualitylens.js measure all \
  --config target/lens-notification-history-2026-10-06/after-tools.config.json
git diff --check
```
