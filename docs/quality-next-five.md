# Five bounded quality improvements

Baseline `d51e8f2`; the incoming `tests/qml/fixtures/bar-reads.json` change is
preserved and excluded from each commit. Evidence is under `target/lens-next-five/`.
Use local qmlqualitylens 0.5.0 with unchanged `qmlqualitylens.config.json` and
`measure quality.qml`. Metrics are advisory; extraction alone is not a reduction
in aggregate effort or proof of correctness. Each step has its own commit.

## 1. Updates history windows

`UpdateHistoryWindow.js` owns pure continuation validation and immutable staging;
`UpdateController` still owns the sole window, requests, one bounded restart,
deadline and publication. Rejected pages cannot partially mutate a staged window.
Publication consumes the accepted window without copying request ownership.

The old `stageHistoryPage` cognitive/cyclomatic/effort was 30/30/134; it is now
6/6/32. Across the new transition/publication functions the maxima are 10/11/44.
The combined weighted effort increases (134 to 160); the benefit is separating
validation from effects and eliminating in-place partial state transitions, not
claiming that extraction deletes work. Existing refresh/selection/viewport tests
and new native F5/continuation tests cover changed totals, retention and cursors.
Qt Updates: 35 passed, no failures/skips. Strict QML lint passes.

## 2. Structured IP operations

`IpEdit` now separates atomic paste classification, fixed-separator deletion
ranges and auto-advance from slot replacement. One offset helper serves selection
removal and insertion. Inspection separates structural/state checks from rendering
without normalizing invalid drafts. No additional editor/session state is stored.

`replace` cognitive/cyclomatic/effort: 41/35/179 → 14/13/66; `inspect`:
33/25/120 → 16/13/59. Helpers are included in the report; maxima are not totals.
150,540 deterministic differential cases cover inspect, replacement and native
buffer edits against the baseline. The 450-check JS vectors pass, as do native
IP control (16) and real Wi-Fi IP fields (9); strict QML lint passes. The native
IPv6 case now distinguishes local substring paste from rejected full selection,
checks no write and undoes before continuing the original discard journey.

## 3. Notification acknowledgement locality

Explicit dispatch now calls small settings, sharing, context-action and app-policy
handlers. `NotificationValidation.settings` owns the settings wire predicate;
one event-version helper fences settings/sharing/DND observations. The sole
request map, consume-before-flush ordering and generation gate are unchanged.
No dynamic handler registry, fallback write path or retry is introduced.

`acknowledge` cognitive/cyclomatic/effort: 35/27/143 → 14/12/66. Native tests add
malformed settings, duplicate completions, queued observations and cancellation
error isolation through real toggle/confirmation routes. Notification center,
catalog, toast and reply suites: 21 passes, no failures/skips. Strict lint passes.

## 4. Shared command registry

Internal `DetailsCommands` owns discovery, scope, chords and the content menu.
`DetailsNavigation` retains fields, transactions and focus restoration, with its
existing command-facing API for controls/hints. There is no second registry or
panel-local key model. Menu geometry and translation context are retained.

The new native command-removal test exposed synchronous close/focus return
re-entering a scoped discovery binding. Invalidation now disables activation
immediately and queues only dismissal; reopening cancels that queued dismissal.
Tests also move one action row between overlapping header/content hosts and
confirm exactly one activation, no added editable stops and retained focus.

DetailsNavigation source lines: 585 → 493; component effort 1165 → 928; locality
20 → 40. The collaborator adds code, so these are ownership-local measurements,
not a claim of net line deletion. Full Qt: 244 passes, no failures, one existing
RHI artwork skip. Strict lint, relative imports and UI role review pass.
