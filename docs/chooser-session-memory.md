# Per-result chooser memory

This is the next step-4 slice of the
[Material Expressive plan](proposals/material-expressive.md), after
[anchored geometry](chooser-geometry.md). Applications and Bluetooth **device**
details opt in. Other domains and Bluetooth's computer-wide adapter settings
retain their existing presentation behavior.

## Delivered behavior

- Each explicitly inspected result remembers whether details are open, its tab,
  and each tab's scroll offset and ordinary browse/editor location. Identity is
  the provider-qualified `Result.key`, never a row index or display name.
- Returning to an inspected result restores its presentation without moving focus
  out of results/search. A new result is list-only. Hover does not select or restore.
- **Right from results** enters the remembered location. If that location was an
  editable control, it can resume editing directly, subject to current capability
  checks. Region Tab and tab changes enter browse mode, not an editor.
- Escape from an editor records browse mode. Explicitly closing details changes
  that result's remembered open state, without changing another result's state.
- Filtering, category/scope changes, reorder, refresh, temporary disappearance,
  reconnect and whole-surface closure do not erase inspected-item records.
  Records live in the retained controller until process exit, never on disk.
- A missing selection closes the presentation without recording an explicit close.
  Selection itself continues to follow `ResultStore`'s existing stable-key/clamp
  policy; memory does not invent a selection or pin a missing backend object.
- Applications resumes fresh resource-history reads when restored Resources
  becomes visible, including after surface closure. UI memory does not freeze
  telemetry or reinstate request IDs.

## Fallbacks and asynchronous ownership

`Ui.ChooserMemory` stores only presentation primitives. Domain controllers supply
current valid tabs and apply requested presentation changes. Selection changes
settle together at the end of the Qt turn so a model reorder's intermediate row
cannot overwrite the remembered item. Explicit navigation settles the current
identity synchronously before deciding whether to open/close/cycle details.

`DetailsNavigation` uses stable, unique control `objectName`s within a tab. It
never restores by target index or localized label. Missing, unnamed or ambiguous
targets fall back to the first available content browse stop. A visible but
disabled/read-only control may retain its browse location but cannot resume
editing. Invalid tabs fall back to the domain's first available tab.

`DetailFlickable` restores pixel scroll offsets after asynchronous page creation
and clamps them to the current content/viewport bounds. Data, layout and live
capabilities remain authoritative. Entering a remembered control can reveal it
at its new position. A changed result while details owns focus returns focus to
results before replacing/closing the view; late loaders do not pull it back.
Closing decoration cannot receive input.

Only registered ordinary controls participate. Password editor locations,
password text, other control values, drafts, payloads, QObject references,
operation IDs and popup-open state are not saved. Whole-surface closure explicitly
closes ordinary menus. Bluetooth still clears/cancels sensitive pairing prompts
and fences their request IDs through its existing recovery logic. Restoring focus
never activates a button, chooses a menu option or dispatches a setting change;
existing native editing, autosave and backend acknowledgement remain responsible
for actual edits and drafts.

## Remaining boundary

This is **per-result** presentation memory, not completion of all session behavior.
The host still requests search focus when reopening a whole surface. Exact
ordinary region/editor/caret restoration on invocation, explicit search/list
viewport snapshots across view recreation, computer-wide settings memory and
remaining domain migrations are subsequent slices. Result editor caret/selection
positions are not serialized here. No sensitive dialog is a restoration target.

## Validation

`tst_chooser_memory.qml` covers independent result/tab state, asynchronous scroll,
non-focus-stealing selection, explicit close, immediate row toggles, reorder,
removal/reconnect, disabled/missing/password editors and invalid tabs. Real
Applications cases exercise category menus, surface closure, capability changes,
missing results and immediate resource-history refresh. Bluetooth recovery tests
exercise its real name editor, result switching and sensitive closure together;
existing pairing, acknowledgement and draft recovery tests remain unchanged.

Strict lint, **151 behavioral cases / 227 Qt passes including hooks**, runtime
smoke and the full sibling-aware gate validate the slice. Live compositor, IME
and screen-reader acceptance remain separate; nothing is deployed or restarted.
Logs: `/tmp/shelllist-memory-validation.log` and
`/tmp/shelllist-memory-full-check.log`.
