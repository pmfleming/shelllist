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
is contained. Search, result rows and domain status share the list pane's left
and right edges; extra panel-specific left gutters must not shrink the row hit
area. The result focus marker stays inside the row's clipped bounds.
Expansion belongs to the **surface**, not each result. Per-result
memory can restore tabs, scroll and field locations, but cannot open/close details
on result movement. Missing results may close unavailable details safely.

## Field browsing

- Only visible, enabled, editable controls are Tab stops. Read-only text, labels,
  headers, tab selectors and action buttons are excluded. Composite controls
  (e.g. a labeled slider) are one stop. Removing a redundant external heading
  must retain its section's `informationOnly` boundary and editable-control
  identities; an untitled group does not become a new browsing stop.
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
- PageUp/PageDown scroll the containing detail page while browsing, including
  read-only charts beside an editable range field; Up/Down remain result
  navigation. Native editors still own keys while editing. Pages without
  editable controls have a non-highlighted scrolling fallback.
- The Power history chart is intentionally pointer-entry-only for now. Do not
  add it to field traversal or expose a keyboard inspection command. Its range
  selector remains an ordinary field; explicit pointer inspection is unchanged.

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

`FormField` labels and supporting/status rows are passive: the contained shared
editor keeps its stable focus identity and transaction. A scrolling `TextEditor`
is still one field. IP/DNS errors become visible on explicit save, without
trapping Tab: saving retains the domain draft, while the existing whole-group
readiness guard blocks invalid/incomplete backend writes. CIDR, unsupported zone
suffixes and full native editing buffers are rejected without accepting a
silently shortened value. Error diagnostics use that same raw-buffer state,
including full buffers whose visible suffix is whitespace; trimming must not
turn a rejected value into an error-free one. No per-keystroke normalization or
cross-field paste write is allowed.

Changes remain **field-local until Enter/Tab**, or an explicit option click on a
shared dropdown with `saveOnOptionClick` enabled (currently Workspace category).
That click is a save, not a preview; arrows and hover still never save.
Typing, other native option selection, slider movement, blur, tab/category changes and surface closure must not dispatch
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
Moving native focus directly between editors discards the previous unsaved draft
before editing the next field; leaving the detail region discards that draft too.
Dropdown option icons are passive; their saved check and selected accessibility
state follow the acknowledged owner value, not the field-local draft or native
menu highlight. The stronger menu highlight identifies the current candidate.
An explicit option click on a `saveOnOptionClick` dropdown closes the menu and
saves through shared navigation, returning to browsing; other dropdown clicks
remain drafts. On/off switches and explicit action buttons remain immediately actionable.
A dropdown's open menu belongs to its field: Enter/Tab saves the highlighted
choice; Escape closes it and discards that edit. It does not add an extra
Escape-to-stop-editing step.

## Highlighting

Only the editable portion is highlighted: input box, slider, selected segment or
switch—not the setting's label, explanatory text, row or card. Browsing has a
subtle tonal highlight plus a compact opaque Primary pill with a Surface keyline.
The marker/keyline pair retains at least 3:1 contrast, including over selected or
filled controls; the low-alpha tint alone is not the focus cue. This is not a
rectangular outline around the control. The top bar opts out of this panel
browsing marker; its pointer feedback and panel markers remain unchanged.
The bar's Media opener and transport share a passive tonal pill, not a combined
hit target or focus stop. Artwork (or its missing/failed-image glyph) opens the
existing Media panel without playback, seeking or pinning. The adjacent transport
buttons retain independent capability-guarded actions and never open the panel;
hover/pressed feedback stays local to each button. Compact density hides transport
but retains the artwork opener. Group padding and gaps have no action. Native
pointer/accessibility route and density coverage lives in `tst_media_chip.qml`;
its rounded-artwork pixel check additionally requires an RHI renderer.
System tray application icons appear only in the Tray chooser, opened by the
bar's ellipsis button; no bar density exposes inline tray application icons.
Horizontal sliders place the marker above
the track. Editing replaces the marker with a stronger tonal highlight and accent
edge, plus native caret/selection feedback. Feedback is immediate and never delayed
by animation. `ToggleRow.focusSurface` is its switch, not the containing row.
The outer panel outline is passive decoration, inset inside the surface's clip
boundary to survive fractional scaling. It is not a focus target or an extra
editable-field highlight and does not change content or input geometry.

## Commands, tabs and exceptions

Command buttons are icon-only Material 3 circles. The shared `DetailsHeader`
centres its larger filled primary beside the title and identity icon; secondary
circles sit below, right-aligned to the same edge. Title and subtitle elide with
an explicit gap before the primary. No primary is invented on information-only
pages. `LabeledAction` supplies passive explanatory text beside contextual
commands; that text/row is neither a hit target nor a field stop. Full labels
remain in accessible names and named command menus. Press feedback keeps the
circle and hit geometry fixed. Expanded-panel secondary circles, including More,
use 32px diameters and 16px icons (two-thirds of 48/24px); primary circles stay
56/28px. Collapsed headers, modal/toast/contextual buttons and named menu rows
retain their existing sizes. Modifier hints remain separate overlays.

`SurfaceActionRow` owns both header tiers and overflow commands. Explicit
`presentation.group: "overflow"` actions stay in More even when the header has
room, reserving one secondary-circle slot; width-overflowed toolbar actions join
that same menu. Hidden menu actions do not register parallel header chords.
A command-only
`CommandGroup` can move between a selected-result host and details without
joining editable traversal or field-page readiness. Shared navigation deduplicates
those live command objects; it does not create parallel command registrations.
`RecoveryActions` shares only the labeled retry/discard layout. Its controls keep
stable domain command names, access keys and independent enabled guards; domain
owners retain drafts, retries, discard effects and acknowledgement handling.
Discovery and loader readiness use the same `DetailsNavigation.fieldBoundary`
predicate, so command, modal and information-only subtrees stay out of field
traversal.
Modal header commands are excluded from panel command discovery and use the
existing contained native modal traversal. See the
[circular action implementation](proposals/circular-panel-actions.md).

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

## Applications action outcomes

The Applications search header has no power switch: there is no corresponding
operation. Search, category filtering and refresh remain available.

Focus and launch hand off to the application and dismiss after successful focus
or checked launch handoff, not mere request admission. Close keeps the chooser
open: window rows disappear only on authoritative snapshots, and the last window
leaves “No open windows” with Launch available. Conflicting commands are blocked
per application, not by freezing result navigation. Check status uses Alt+K and
read-only recovery; progress text is not a field stop. A removed window command
returns to shared detail browsing. Closing a view does not cancel its submitted
operation, and a late reply cannot dismiss a reopened or newly browsed view.
Background errors notify without reopening. See [application action outcomes](application-actions.md)
for ownership, acknowledgement, recovery bounds and interaction tests.

## Application detail commands

Application window and desktop-action groups use passive shared `DetailColumnCard`
containers and remain information/commands only, not editable fields. Tab uses the page's non-highlighted scrolling fallback; PageUp/
PageDown scroll, and Up/Down continue browsing application results. Each window's
More circle opens the shared named command menu restricted to that window's
Focus/Close commands. Close has no adjacent destructive hit target or claimed
undo. Alt+J still exposes all window and arbitrary desktop actions, regardless
of scroll position. These menus share modal shortcut guards, native traversal
and focus restoration; removing their owning window closes them rather than
redirecting Enter to a different window. Full labels and stable daemon IDs are
retained. Compact number-first window rows keep workspace/current-window badges
and acknowledged focus-success checks passive, with full accessible names. Only
the title/metadata composition changes: no field stops, row-wide hit targets or
selection highlights are added. Long titles and error/progress text can expand
the row; Focus/More retain shared 32px command circles and existing guards.
See [application details](application-details.md) for the visual and capability
contract and Qt interaction coverage.

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
Media result Enter invokes the selected player's capability-guarded Play/Pause
primary action, retaining list focus and expanded/collapsed state. It never routes
to a different active player or falls back to inspection when playback is disabled
or busy. Right remains the action-free way to expand details.
The Media playback card is information-only: contained square artwork, content
labels, read-only progress and numeric elapsed/remaining/rate follow the inspected
player without gaining focus, pinning a player or invoking transport. Tab continues
directly to the shared Pin to bar switch and Bar controls dropdown. Only explicit
Enter/Tab saves the control-mode draft; acknowledged mode and capability guards
choose track/seek header commands, with the alternative pair in More. Playback
state uses icons and timing uses numbers, with full accessible descriptions;
there is no persistent shortcut legend or instructional footer. Errors remain text.
Recognition changes presentation/search only, never the MPRIS routing or pin ID.
See [Media presentation and shortcut diagnosis](media.md).

Applications' Resources page combines snapshot readings and history in five
information-only groups. Its shared 30m / 2h / 24h segmented field is the sole
editable stop and controls both period totals and history. Pointer choice remains
a local draft; Enter/Tab saves and requests the new range, Escape or leaving the
editor discards without a history request. Tab/Shift+Tab wrap on that field;
charts, metadata and statistics never become additional stops. The shared
icon-only information command **Alt+H** toggles read-only Measurement details,
also available by name in the shared **Alt+J** content menu. Opening reveals the
heading if needed; PageUp/PageDown scroll the page. Disclosure has no backend
side effects and adds no chart-inspection key model. See
[resource measurement semantics](application-resources.md) and
`tst_application_resources.qml` for actual key/pointer coverage.

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
Layout/policy telemetry during an unacknowledged Preview must not replace its
local draft or mark it stale merely for that pending change. Trial topology
changes still invalidate the draft; acknowledgement/error guards remain intact.

Applications Settings uses one shared `FormField`/`DropDownList` named
**Workspace category**, with category-only labels and separate semantic icons.
Its label and supporting/status text are passive; there is no separate launch
consequence footer. Only `applicationCategory` joins field traversal. No-op forward/reverse
wrap does not submit; saving a change disables the field until acknowledgement,
so traversal temporarily falls back to the page. Clicking a category option also
saves immediately via shared `saveOnOptionClick`, with the same acknowledgement,
no-op and retry guards; keyboard arrows remain drafts until Enter/Tab.
Pending/error feedback is
scoped to the originating application; a mismatched saved mapping is not shown
as unassigned. `tst_application_settings.qml` covers actual keyboard/pointer
transactions, saved checks versus drafts, failure/retry and acknowledgement.

Notifications search uses the daemon catalog, including unloaded retained rows
within its documented recent-history scope. Typing issues debounced reads only;
query changes supersede old pages, and F5 refreshes without replaying any
command. Page append and atomic same-query refresh preserve keyed selection,
viewport and reply-editor transactions. Stale cursors retry reads; they must not
merge revisions or resurrect deleted rows. A superseded read's success or error
must not retire a newer read or clear a reply draft. Incomplete refresh pages stay
unpublished on read failure, epoch/revision changes, or loss of permission to
continue history loading. Queued revision events are applied before accepting a
page. `tst_notifications.qml` covers representative ordering/validation cases, actual
search key delivery, cursor recovery and reply/viewport retention.

Wi-Fi Sign in remains **Alt+I**, never a field Tab stop. It requests and claims a
daemon-owned portal intent before the frontend executes browser/workspace focus;
Tab/arrows/Enter field transactions never invoke it. The bar's explicit fallback
uses the same transaction. Failure or transport recovery does not replay an
uncertain launch. Only a nonempty owned response ID in prepare/claim/complete
may advance the transaction; an unowned response cannot retire an executing
browser launch. Claimed ID, episode and URL must match, with a finite future
expiry. `tst_wifi_portal.qml` exercises actual command/navigation keys,
claim acknowledgement, late replies, failures and UI disappearance.

Display arrangement follows the same command model: **Alt+L/U/D/R** invokes the
Left/Above/Below/Right buttons below the monitor map. These actions modify the
local layout draft, not the backend. Buttons and the map are not Tab stops;
plain arrows remain result/native-editor navigation. With 3+ eligible monitors,
the reference dropdown is an ordinary editable field: Enter/Tab saves the target
selection, Escape discards it, and changing the target alone never moves a screen.
Pointer edge-dragging uses a transient ghost, committing to the draft only on a
valid drop; Escape cancels the gesture without also closing details. Preview stays
the explicit backend boundary. Native tests retain representative command/drop
routes, reference save/discard, guards and cancellation; JavaScript checks cover
all four directional calculations and fractional/rotated placement. Shared
header/bar tests cover overflow revelation rather than repeating a per-panel size
matrix. The [2026-10-06 test review](reviews/test-pruning-2026-10-06.md) records
reduced coverage, including native End/RTL/vertical matrices, outside-drop and
some restoration/consumer paths. Shared transactions, actual command keys and
domain safety guards remain tested; these reductions do not change or relax the
interaction contract.
