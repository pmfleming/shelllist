# Chooser session memory

Delivered step-4 slices of the [Material Expressive plan](proposals/material-expressive.md),
after [anchored geometry](chooser-geometry.md):

- Applications, Bluetooth devices, Wi-Fi, Clipboard, Displays, Time & Weather
  and individual notifications use per-result presentation and ordinary invocation focus.
- Audio, Media and Tray use the same independent records. Media pins/control modes
  are separate daemon-owned settings, never replayed from presentation memory;
  native tray-menu handles and open state remain transient.
- Battery and Activity use the single-panel focus adapter; Activity's todo draft
  remains controller-owned. Notifications retains its existing reply draft owner.
- Bluetooth settings have a separate per-adapter cache with per-tab scroll;
  Battery settings have their own computer-wide record. Wi-Fi advanced pages
  now use the shared scroll boundary and ordinary settings have stable keys.
- Unique named list/header controls can restore focus without activation; removed,
  ambiguous or disabled targets fall back to search. Custom unnamed controls still
  fall back safely rather than guessing an identity.

## Per-result presentation

Initial page layout is part of restoration readiness: a newly incubated control
is not revealed against zero-height content. Explicit reveal commits scroll
bookkeeping before moving, so a queued initial restore cannot undo it. New input
and invocation/context cancellation still supersede pending restoration.

- Each inspected result remembers its valid tab and each tab's scroll offset
  and ordinary browse/editor location. Identity is the provider-qualified
  `Result.key`, never a row index or display name.
- Returning to a result restores tabs/locations **without moving focus out of
  results/search**. Expanded/collapsed mode belongs to the surface and remains
  unchanged on result movement, including previously unseen results.
- **Right from results** expands without entering fields. Tab enters browsing;
  Enter then edits. See the mandatory [interaction contract](chooser-keyboard-workflow.md).
- Ordinary text editors retain cursor and selection direction, not their values.
  Positions are clamped to the current text. Native selection changes are captured
  before a pointer result switch can replace the current identity.
- Escape discards the current field transaction and records browse mode.
  Explicitly closing details changes the surface expansion state for all results.
- Filtering, category/scope changes, reorder, refresh, temporary disappearance,
  reconnect and closure do not erase inspected-item records. A missing selection
  closes presentation without recording an explicit close. Selection continues
  to follow `ResultStore`'s stable-key/clamp policy.
- Restored Applications Resources immediately requests fresh history. Memory
  neither freezes telemetry nor reinstates request IDs.

## Invocation focus

Closing or switching away snapshots ordinary focus **before** hiding content or
cancelling sensitive prompts. The pre-hide hook leaves domain cleanup in its
existing post-hide order; it freezes presentation and closes ordinary menus.
Reopening restores Search, Results, or Details;
a registered detail target can resume browsing or editing, subject to current
identity, tab and capability checks. A first invocation defaults to search.
Unique registered list/header controls restore through `FocusLocations`; unknown,
ambiguous or unavailable controls fall back to search rather than inheriting an
old detail editor. Expanded detail headers are no longer content browse targets;
old header target records fall back to content. Tab/Shift+Tab stay in the current
detail tab and supersede deferred restoration; header shortcuts never restore
focus or replay effects.

`Ui.ChooserSession` keeps a separate primitive snapshot in the retained
controller's `focusMemory`. It includes:

- the ordinary region and stable result/tab context (adapter identity and tab
  for computer-wide Bluetooth settings);
- an ordinary detail target and browse/edit mode;
- query/editor cursor and selection positions;
- the result viewport's top visible stable key and within-row pixel offset.

The query and selected result remain controller-owned; restoration never reselects
or writes query/control values. Viewport bookmarks survive visual-tree recreation
and reorder, wait for keyed-model chunks, and clamp to current bounds. A missing
bookmark or changed selected identity falls back to normal selection revelation.
New selection, query editing or scrolling takes precedence over a bookmark.
Notification model batches emit `resultsAboutToChange(preserveViewport)` before
changing their presented records and `resultsChanged` after reconciliation. The
shared result frame captures a keyed viewport before index changes and restores
it once after the batch. Equal model payloads are not reassigned. Explicit detail
collapse emits `detailsClosing` so the shared surface discards a field transaction
before its loader is destroyed; this also makes rapid reply close/reopen safe.

Host visibility, controller-ready and content-ready paths call `restoreUiFocus()`
instead of issuing competing search-focus requests. Restoration is consumed once
per activation. New navigation, native focus/input, modal prompts and closure
cancel deferred restoration. Queued explicit-search and modal-fallback callbacks
are fenced by the UI generation, including rapid close/reopen cycles.

Bluetooth refreshes on activation. During that read, a remembered detail location
is shown in browse mode; the editor resumes only after refresh and queued field
reconciliation, if still valid and no newer interaction occurred. A changed
result/adapter/tab falls back to results or search instead of editing another
object. Disabled/read-only targets stay in browse mode. Ordinary menus reopen
**collapsed**, and no sensitive dialog is a restoration target.

## Fallbacks and ownership

`Ui.ChooserMemory` stores presentation primitives. Domains supply valid tabs and
apply presentation changes. Queued selection/tab changes settle together so a
model reorder's intermediate row cannot overwrite a record. Explicit navigation
and deactivation synchronize the current identity first.

`DetailsNavigation` resolves unique control `objectName`s within the current tab,
never indexes or localized labels. Missing, unnamed, ambiguous or password
targets fall back to content browsing. Asynchronous pages may finish restoration
only while their invocation/context still owns focus. `DetailFlickable` restores
per-result pixel offsets after page creation and clamps them to current bounds;
entering a remembered target reveals its current position.

Neither cache stores text, password positions, control values, drafts, payloads,
QObject references, operation IDs, IME preedit state or popup-open state. State
is process-local and never written to disk. Native controls and domain-owned
drafts remain responsible for committed changes, acknowledgement and recovery.
Uncommitted field transactions are discarded on closure; invocation restoration
may resume editor focus but never restores unsaved field values or publishes edits.
Focus restoration cannot activate a button, select a menu option or dispatch a
setting change.

Bluetooth still clears/cancels sensitive pairing prompts and fences dismissed
request IDs through its existing recovery logic. A modal preserves the preceding
ordinary location, not the prompt's credentials or focus. Closing a prompt no
longer queues an unconditional search-focus request that could outlive closure.

## Remaining boundary

This is not a guarantee of exact focus for arbitrary custom controls. Independent
Bluetooth adapter/tab and Battery settings records are delivered. Unknown or
ambiguous targets still deliberately fall back. Revealed Wi-Fi password fields
remain classified sensitive independently of their visual echo mode. Native text
horizontal scrolling follows Qt's caret revelation rather than a separate pixel
snapshot. Disk persistence and restoring sensitive dialogs are deliberately out
of scope.

## Validation

`tst_chooser_memory.qml` covers per-result/tab state, asynchronous pages,
non-focus-stealing selection, close/reorder/removal/reconnect and capability
fallbacks. Invocation tests exercise search/results/browse/editor focus, backwards
selections, current-value clamping, keyed viewports, destroyed/recreated views,
new-input cancellation, focus-loss context changes and stale queued callbacks.
Real Applications tests cover collapsed-menu restoration and fresh history.
Bluetooth tests cover device and adapter editors (including an empty device list),
refresh readiness, changed adapters, newer navigation and sensitive-prompt
cancellation without replaying edits. Existing acknowledgement/recovery checks
remain intact.

Strict lint, **175 behavioral cases / 251 Qt passes including hooks**, runtime
smoke and the full sibling-aware gate pass. Live compositor/input-mask, hardware
IME and screen-reader acceptance remain separate. Nothing is deployed or restarted.
Logs: `/tmp/shelllist-session-validation.log` and
`/tmp/shelllist-session-full-check.log`. Both expanded memory and Bluetooth suites
also passed three consecutive runs in `/tmp/shelllist-session-repeat.log`.

One local run emitted Qt's intermittent “items in the process of being created
at engine destruction” warning after Displays teardown. Isolated repetitions
reproduced it at committed baseline `1a92090` and in this slice; the full gate
was clean. This separate teardown issue remains unresolved, with no suppression
added. Evidence: `/tmp/shelllist-session-displays-repeat.log`.
