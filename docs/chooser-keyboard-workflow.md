# Shelllist interaction contract

**Required for every current and future panel.** This document is the normative
search/list/field interaction model, superseding older keyboard decisions in
proposals and reviews. Shared implementation lives in `qml/Shelllist/Ui/`.
Applications, Bluetooth, Wi-Fi, Clipboard, Displays, Time & Weather,
Notifications, Audio, Media and Tray use `ProviderChooserSurface`; Battery and
Activity use `PanelSurface`. Domain-specific actions do not override field keys.

## Search and results

| Focus | Key | Required behavior |
| --- | --- | --- |
| Search | Left / Right | Native cursor/selection movement |
| Search | Up | Stay in search; do not change result selection |
| Search | Down | Focus/select the first result |
| Results | Up / Down | Previous/next result; keep expanded/collapsed mode unchanged |
| First result | Up | Return to search |
| Results | Right | Expand details **without transferring focus** |
| Results | Left | Collapse details |
| Results | Enter | Existing domain primary action |
| Results | Printable text | Focus search and insert at its retained cursor/selection |
| Results, details open | Tab | Enter field browsing, not editing |

Outside details, Tab/Shift+Tab cycle the available search/results/details regions.
They never open details or select a different result. Within details, traversal
is contained. Expansion belongs to the **surface**, not each result. Per-result
memory can restore tabs, scroll and field locations, but cannot open/close details
on result movement. Missing results may close unavailable details safely.

## Field browsing

- Only visible, enabled, editable controls are Tab stops. Read-only text, labels,
  headers, tab selectors and action buttons are excluded. Composite controls
  (e.g. a labeled slider) are one stop.
- Tab goes forward; Shift+Tab goes backward. Both wrap at either end.
- Up/Down select the previous/next **list result**, retaining open details and
  returning focus to the result list. They never traverse fields. In a panel
  without results, they do nothing while browsing.
- Enter starts editing the highlighted field. **Right is not an edit alias.**
- Enter on an on/off switch toggles immediately, remaining in browse mode.
  A two-option segmented selector is **not** a switch: it still requires editing
  and save/discard.
- Left or Escape leaves details while browsing. Domain back-navigation (such as
  a Displays subpage) still takes precedence over closing its parent page.
- PageUp/PageDown scroll a read-only page; Up/Down remain result navigation.
  Pages without editable controls have a non-highlighted scrolling fallback.

## Editing transactions

| Key | Required behavior |
| --- | --- |
| Arrows | Native editor behavior: cursor movement, slider adjustment, option selection |
| Enter | Save this field and return to browsing it |
| Escape | Discard this field's changes and return to browsing it |
| Tab | Save, move forward, and enter the next editor |
| Shift+Tab | Save, move backward, and enter the previous editor |

Forward/reverse traversal wraps in edit mode too. If saving disables, hides or
removes the current field, continue from its original position, skipping any
neighbours that are now unavailable; do not restart at the first/last field.
Arriving at a switch highlights it **without toggling it** and returns to
browsing. Actions are never traversal stops. Shift+Enter remains available for a
newline in multiline editors.

Changes remain **field-local until Enter/Tab**. Typing, native option selection,
slider movement, blur, tab/category changes and surface closure must not dispatch
a deferred field's setting write. Leaving via a route other than save discards
the uncommitted field edit. Already submitted operations and domain failure/retry
state are not undone. A save is a request, not an acknowledgement: existing daemon
validation, capability guards, errors and retry mechanisms remain authoritative.

Source bindings must survive every transaction, including no-op cancellation,
blur and native slider Home/End edits. Incoming snapshots must not overwrite an
active local draft. On exit, restore the source binding so later backend or
result changes remain visible; a deferred field's discard reveals the latest
source value if it changed during editing. Unbound fields retain their saved
draft or revert to their captured original on discard.

The explicit exception is a continuous preview control such as volume or
brightness: set `livePreview: true` on `ValueSlider`/`LabeledValueSlider`.
Adjustments publish live, Enter/Tab retain the value, and Escape publishes the
value captured at edit entry to restore it. Other sliders default to deferred
save, including battery thresholds and Bluetooth timeouts.

Pointer entry into a shared field uses the same transaction as keyboard entry.
On/off switches and explicit action buttons remain immediately actionable.
A dropdown's open menu belongs to its field: Enter/Tab saves the highlighted
choice; Escape closes it and discards that edit. It does not add an extra
Escape-to-stop-editing step.

## Highlighting

Only the editable portion is highlighted: input box, slider, selected segment or
switch—not the setting's label, explanatory text, row or card. Browsing has a
subtle tonal highlight. Editing has a stronger tonal highlight and accent edge,
plus native caret/selection feedback. Feedback is immediate and never delayed by
animation. `ToggleRow.focusSurface` is its switch, not the containing row.

## Commands, tabs and exceptions

- Action buttons use **Alt+letter**, not Tab. `ActionControl.accessKey` defines a
  command; `commandScope` can limit a repeated command to the current field/row
  (e.g. Alt+H for its help). Duplicate active letters fail closed.
- Selected-result commands can use `ProviderChooserSurface.additionalCommandItem`
  with `commandsWithoutDetails`. They share `DetailsNavigation`'s access keys,
  command menu, modifier hints and modal guards even while details are collapsed;
  they do not create another field-navigation region. Notifications uses this
  for a single selected message: Enter invokes its live default action, otherwise
  opens details without dismissing it. Alt+O opens, Alt+D dismisses, Alt+Z snoozes,
  Alt+C copies text and Alt+R opens inline reply (or sends from its editor).
- Alt+J opens the content-action menu for unassigned/repeated commands, such as
  arbitrary application desktop actions and per-window commands. This keeps
  unbounded action lists keyboard-accessible without putting them in field Tab
  order. Prefer explicit letters for common commands.
- Alt+M opens the existing header overflow menu. Alt+S takes a screenshot.
  J, M and S are reserved for these purposes. Command menus use conventional
  arrows/Tab, Enter/Space and Escape and restore preceding focus on close.
- Ctrl+Tab / Ctrl+Shift+Tab change detail pages, discarding any uncommitted field
  edit and entering browsing on the new page. They do not steal result focus.
- F5 refreshes where supported. Alt+Enter invokes search's trailing action.
- Required-input modal dialogs keep conventional contained native Tab traversal
  and their explicit submit/cancel behavior. They are not list/detail editors.
  While a modal or command menu owns input, underlying field/command shortcuts
  must not run. Sensitive inputs never enter presentation memory.

Header modifier-held hints remain: holding Alt shows command badges after
250ms; holding Ctrl shows the detail-tab chord. AltGr does not show hints.
There is no F1 overlay, hover tooltip or plain-letter action shortcut.

## Implementing or extending a panel

1. Use `ProviderChooserSurface` or `PanelSurface`; their shared keyboard
   workflow is mandatory, not an optional migration mode. Do not add local
   Up/Down field traversal or Right-to-edit.
2. Use shared `TextField`, `TextEditor`, `DropDownList`, `SegmentedControl`,
   `ValueSlider`/`LabeledValueSlider`, `ToggleRow` and `ToggleSwitch` controls.
   Assign stable `objectName`/`focusKey` identities for ordinary restoration.
3. For deferred settings, consume **`edited` / `selected` / `editingFinished`**,
   not `textChanged`, `valueChanged`, native `activated`, or focus loss. These
   public edit signals publish only on save inside a navigation boundary.
   `FieldEditSession` owns only the temporary original/draft transaction; it
   never stores values in presentation memory. Raw controls outside a panel
   boundary retain their native behavior (including required-input dialogs).
4. Multiline/lease-owning domains use `TextEditor.edited` and
   `editFinished(saved)` to submit/cancel their domain session. Clipboard is the
   reference adapter; it must not debounce-save per-keystroke drafts.
5. Keep acknowledged values distinct from choice drafts. Do not mark a proposed
   backend setting acknowledged just because Enter was pressed. Preserve domain
   validation and in-flight guards.
6. Give commands explicit, non-conflicting `accessKey` letters or expose them
   through the shared content menu. Use `commandScope` for field-specific help
   or repeated row actions. Never make commands ordinary field stops.
7. Custom editable controls must integrate a `FieldEditSession`, publish only
   at the appropriate transaction boundary, and join `DetailsNavigation`'s
   typed editable/session dispatch. Native-value editors set the session's
   `valueProperty` (`text` or `value`) to preserve the caller's binding during
   edits and rollback. Keep read-only/capability guards in the session's
   `available` binding beside the control. Native editors/popups that consume
   transaction keys call `FieldEditSession.handleKey`; multiline editors set
   `multiline: true` to retain Shift+Enter. `ActionMenu` shares header/content
   command navigation without owning domain effects. Add behavioral tests before
   adding a new control family; do not implement a parallel keyboard model in a
   panel.
8. Exercise both forward/reverse wrap, on/off arrival, local-save/discard,
   live-preview rollback, list movement, disabled/removed editors and command
   modality. Update this contract when an intentional model change is approved.

See [session memory](chooser-session-memory.md) for focus/caret restoration and
[geometry](chooser-geometry.md) for revealing controls without moving the list.
Neither restoration nor a browse highlight may activate a setting or command.

## Validation

`tests/qml/tst_field_interaction.qml` checks actual key delivery for transactions,
wrapping, choice drafts, two-option selectors, live rollback, pointer entry,
highlight boundaries, source-binding preservation and positional traversal when
save disables, hides or removes a field. `tst_chooser_keyboard.qml`,
`tst_chooser_memory.qml` and the domain suites cover navigation, asynchronous
content, modal guards, native menus, ordinary restoration and real setting
acknowledgement/recovery paths.
Run `tests/run-qml-tests.sh` in the development environment. Strict lint is
`tests/run-qmllint.sh`. Hardware IME, live compositor and screen-reader acceptance
remain separate from offscreen tests. Displays' mode selectors consume daemon
mode IDs and structured geometry: Enter/Tab saves only to the local layout draft,
Escape discards the field edit, and Preview remains the explicit backend boundary.
`tst_displays.qml` exercises this with opaque mode IDs and actual key delivery.

Notifications search uses the daemon catalog, including unloaded retained rows
within its documented recent-history scope. Typing issues debounced reads only;
query changes supersede old pages, and F5 refreshes without replaying any
command. Page append and atomic same-query refresh preserve keyed selection,
viewport and reply-editor transactions. Stale cursors retry reads; they must not
merge revisions or resurrect deleted rows. `tst_notifications.qml` covers actual
search key delivery, late replies, cursor recovery and reply/viewport retention.

Wi-Fi Sign in remains **Alt+I**, never a field Tab stop. It requests and claims a
daemon-owned portal intent before the frontend executes browser/workspace focus;
Tab/arrows/Enter field transactions never invoke it. The bar's explicit fallback
uses the same transaction. Failure or transport recovery does not replay an
uncertain launch. `tst_wifi_portal.qml` exercises actual command/navigation keys,
claim acknowledgement, late replies, failures and UI disappearance.

Display arrangement follows the same command model: **Alt+L/U/D/R** invokes the
Left/Above/Below/Right buttons below the monitor map. These actions modify the
local layout draft, not the backend. Buttons and the map are not Tab stops;
plain arrows remain result/native-editor navigation. With 3+ eligible monitors,
the reference dropdown is an ordinary editable field: Enter/Tab saves the target
selection, Escape discards it, and changing the target alone never moves a screen.
Pointer edge-dragging uses a transient ghost, committing to the draft only on a
valid drop; Escape cancels the gesture without also closing details. Preview stays
the explicit backend boundary. Native tests cover all four commands/drop edges,
reference save/discard, guards, cancellation, and narrow-view focus revelation.
