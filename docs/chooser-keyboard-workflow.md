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

`FormField` inline icons/names, separators, state badges and disclosed help are
passive: the contained shared editor keeps its stable focus identity and
transaction. A single-line or expanded scrolling `TextEditor` is still one field. IP/DNS errors become visible on explicit save, without
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
hover/pressed feedback stays local to each button. Every density retains the
artwork opener and all three transport controls. Unsupported actions and missing
players disable transport without hiding it; artwork still opens Media directly.
No hover, disclosure or secondary click is required to reach transport. Group
padding and gaps have no action. Native pointer/accessibility route and density
coverage lives in `tst_media_chip.qml`; its rounded-artwork pixel check additionally
requires an RHI renderer.

The chromatic bar uses fixed-size icon-only category targets (Shell, Browser,
Code, Media, Text for workspaces 1–5), never active-workspace labels or focused-app
icon substitution. Acknowledged selection paints the accent glyph immediately
at 22px rather than 20px, without a resting tile or lower dot/dash. Occupancy uses
regular/semibold glyph weight and neutral/muted foregrounds; it is not a disabled
state. Existing static urgency outlines and upper-right marks remain distinct.
These visual changes add no focus targets or new keyboard behaviour.
Workspaces stay left, system status right, and Media is centered when space permits,
clamped between the measured edge groups otherwise. Narrow widths reduce gaps and
omit the numerical date, not actions; below the full strip's minimum width the
existing explicit overflow scrolls it. Workspace overflow still scrolls independently
and reveals the active workspace. Neither layout nor reveal dispatches an action.

Battery is one direct action with a continuous bottom-up fill and a reserved,
non-overlapping external state-mark slot. Lightning, plug, check, warning and
unknown marks never cover the fill and do not become independent targets. Invalid
or absent telemetry stays unknown, not a false zero/full value; daemon warning and
critical flags remain authoritative. Only new known fill readings may interpolate
for 160ms, respecting reduced motion. Clock/date form one numerical action opening
Time & Weather, with full date/timezone in its accessible name. The bar adds no
field Tab stops. `tst_balanced_dashboard.qml` covers actual routes, acknowledged
workspace selection, overflow, fill pixels and battery state boundaries.
System tray application icons appear only in the Tray chooser, opened by the
bar's ellipsis button; no bar density exposes inline tray application icons.
Horizontal sliders place the marker above
the track. Editing replaces the marker with a stronger tonal highlight and accent
edge, plus native caret/selection feedback. Feedback is immediate and never delayed
by animation. `ToggleRow.focusSurface` is its switch, not the containing row.
The outer panel outline is passive decoration, inset inside the surface's clip
boundary to survive fractional scaling. It is not a focus target or an extra
editable-field highlight and does not change content or input geometry.

## Compact field presentation

**Option C (compact value rows) is the shared default**, including editable
fields: no filled resting box or routine label/helper rows above/below it.
`FormField` keeps a semantic purpose icon and concise inline name; full names,
units, required/optional state and guidance remain in native accessibility.
Names may wrap instead of clipping at narrow/translated widths. Resting rows
have a passive separator; only the native editor gets browse/edit feedback.

Read-only values retain normal text contrast and a prominent passive lock badge,
not a tiny “read-only” footer or an unlock command. Unavailable editors use a
separate blocked indicator, without fading their values. Empty read-only values
show a dash, never an example input masquerading as an observation. Clipboard's
explicit `editingAllowed` gate still permits entry to acquire its native edit
lease before the text becomes writable; presentation must not block that path.

Ordinary guidance is disclosed explicitly using the shared Help command, never
on hover. Editable-row Help uses scoped Alt+H. Read-only Help/Copy commands are
unscoped named entries in Alt+J, since those rows cannot be selected with Tab.
They remain outside field traversal. Copy is opt-in and routed through the
existing domain publisher/guards; secrets never acquire automatic copy actions.
Existing external Help commands can suppress the embedded button without losing
accessible guidance. Errors, safety/recovery messages and in-flight status remain
visible; no empty supporting row is reserved. DNS/other native multiline editors
start at one line and grow to a bounded scrolling area; explicitly sized document
editors retain their size and single-field transaction. See the
[implementation record](reviews/compact-text-fields.md) and
`tst_compact_fields.qml`, `tst_ip_fields.qml`, `tst_material_feedback.qml`.

Bluetooth’s **Restore original name** is an icon-only trailing action inside the
shared Name text field, not a separate labeled/explanatory row. Its accessible
name and Alt+O command remain available through shared command navigation, never
Tab traversal. The icon retains its geometry when disabled; dirty-name, busy,
missing-original and already-original guards and authoritative acknowledgement
are unchanged. `TextField.trailingAction` exposes the shared embedded command for
identity/access-key configuration. `tst_bluetooth_recovery.qml` covers its actual
pointer/key routes, native save/discard, placement and disabled guards.

## Commands, tabs and exceptions

Disabled commands normally retain their geometry and visible icons; only the
shared action row's last-resort narrow-width policy below may omit them. Unfilled
buttons use surface-appropriate foregrounds, not accent-fill foregrounds on
transparent backgrounds. Disabled commands never activate or join field traversal.

Command buttons are icon-only Material 3 circles. Result-list actions use shared
borderless `FlatIconButton` styling without changing hit geometry or key routing.
The shared `DetailsHeader`
centres its larger filled primary beside the title and identity icon; secondary
circles sit below, right-aligned to the same edge. Title and subtitle elide with
an explicit gap before the primary. No primary is invented on information-only
pages. `LabeledAction` supplies passive explanatory text beside contextual
commands; that text/row is neither a hit target nor a field stop. Full labels
remain in accessible names and named command menus. Press feedback keeps the
circle and hit geometry fixed. Expanded-panel secondary circles, including More,
normally use 32px diameters and 16px icons (two-thirds of 48/24px); primary circles
stay 56/28px. Collapsed headers, modal/toast/contextual buttons and named menu rows
retain their existing nominal sizes. Modifier hints remain separate overlays.

`SurfaceActionRow` owns both header tiers and explicit menu commands. Content
command groups can reuse it with `headerCommands: false`; their live buttons join
the existing content-command registry and Alt+J, not a parallel header registry.
They remain outside field traversal and share the same responsive layout. Toolbar
commands remain directly visible: as width tightens, first reduce their horizontal
gaps from 8px to 2px, then shrink secondary circles/icons to a shared minimum of
28/14px, then omit only as many disabled commands as necessary (retaining earlier
ones first). All dimensions scale with `uiScale`. Widening restores the commands,
sizes and spacing; newly enabled commands reappear immediately. The primary never
shrinks. If enabled commands alone still cannot fit, wrap them into right-aligned
rows at the minimum size rather than hiding them or creating More. Header height
includes every row. Command buttons remain outside field Tab traversal and retain
their Alt+letter shortcuts and capability guards at every size.
Explicit `presentation.group: "overflow"` actions still use More for intentional
named menus, reserving a secondary-circle slot; width pressure never moves toolbar
actions there. Hidden menu actions do not register parallel header chords.
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
  host for selected-app Silence (Alt+Q) and Delete (Alt+D) while collapsed.
  Expanded app pages own those commands instead. The center has no Message page
  or sender-action commands; notification popups retain their own guarded actions.
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

## Notifications app groups and detail tabs

The left results remain app groups in every state; Up/Down never browses an
embedded message list. Enter always opens **Notifications**, including singleton
apps, without invoking a sender action or selecting an implicit newest message.
Right/Left expand/collapse as usual. Shared detail tabs are icon-only
**Notifications / App controls**, with accessible names retained. Ctrl+Tab cycles
only those two pages. App changes preserve surface expansion and restore
app/query-local period and tab. No lifecycle filter, status badge, or separate
archive is presented: counts always describe notifications.

App rows lead with the latest notification's content. Time, application name and
total notification count are secondary metadata, followed by Silent when relevant.
Duplicate app-name summaries/body text are suppressed; full content and matching
counts remain accessible even when the row elides. Identity, selection and command
scope still belong to the application, not the previewed record.

App rows expose Silence and Delete as separate shared borderless icon commands,
matching other panels' list actions. Their
pointer scope is that row, not an implicit newest message or a selection change.
Alt+Q / Alt+D target the selected app in collapsed results and expanded app pages.
Expanded app headers have one filled primary, Silence/Unsilence (Alt+Q), beside
identity; Reset app defaults (Alt+E) and Delete (Alt+D) are secondary circles below.
Reset is not a separate settings-content row. Result Enter still opens the list,
never silently changes delivery. Silence suppresses interruptions, not collection. App controls use shared deferred
popup/duration dropdowns and immediate grouping/DND-bypass switches; acknowledged
policies persist across daemon restarts. Sound playback and retention-policy
editors are not exposed without supporting backend capabilities.

Notifications starts with up to three newest matching records, individually
visible, followed by **Today / This week / This month / Older**, initially closed.
These four native periods exclude the three previews and are mutually exclusive:
local today first, then the calendar week beginning Monday, then the calendar
month, then everything older. Empty groups have neither a title nor a disclosure
control, and return when their native count becomes nonzero. One period
opens at a time; exact action-free repetitions on the same local date become
bounded stacks with individually addressable records. Counts, grouping and search
belong to the native catalog, not the loaded transport slice. Windows append on scroll;
there is no Page field or next/previous-page command. Period/stack expansion and
individual Delete are commands (also in Alt+J), never field Tab stops or row-wide
sender actions. Notification cards have no Read/right-arrow navigation; their
Delete and stack-expansion buttons are borderless. `DetailListView` shares
`DetailFlickable`'s non-highlighted Tab fallback and PageUp/PageDown scrolling;
Up/Down still select application results.

Delete prepares a native snapshot and opens a shared confirmation modal with its
actual count. App/global deletion includes retained records outside search and
older than the recent search window. Confirmation targets stable record identities,
so later arrivals survive. Cancelling releases the token; closing the panel rejects
late preparation replies. No optimistic removal, automatic mutation retry, or
claimed undo. Only acknowledged deletion refreshes the collection; app preferences
survive. Modal input suspends underlying navigation and commands.

The Message tab, its detail reader, reply editor and sender commands are removed
from this center; there is no hidden tab to restore or navigate to. Alt+D remains
selected-app deletion, while a card's Delete targets only its stable record ID.
Popup sender actions/replies retain their existing acknowledgement and lifecycle
guards. Tab changes still discard only uncommitted app-control edits.

Native windows stage refreshes atomically and fence stale revisions, epochs,
queries, period changes and local-midnight rollover. Recent previews and period
windows publish atomically, without duplicated records. `tst_notifications.qml` and `tst_notification_center.qml`
cover actual app/card commands and menus, icon tabs, empty-period visibility,
shared scrolling, policy transactions, confirmation/cancel, stale responses,
bounded rendering and app-control draft preservation.
Daemon tests cover persistence, grouped dates/stacks, exact deletion scope,
restart, policy enforcement and new arrivals during confirmation. See
[notification center](notifications.md) for implementation and capability limits.

## Applications action outcomes

The Applications search header has no power switch: there is no corresponding
operation. Search, category filtering and refresh remain available.

Focus and launch hand off to the application and dismiss after successful focus
or checked launch handoff, not mere request admission. Close keeps the chooser
open: window rows disappear only on authoritative snapshots, and the last window
leaves “No open windows” with Launch available. Conflicting commands are blocked
per application, not by freezing result navigation. Check status uses Alt+K and
read-only recovery; progress text is not a field stop. A missing/malformed status
reply retires only its owned read so Check status remains usable, never replaying
the mutation or announcing completion. A removed window command
returns to shared detail browsing. Closing a view does not cancel its submitted
operation, and a late reply cannot dismiss a reopened or newly browsed view.
Background errors notify without reopening. See [application action outcomes](application-actions.md)
for ownership, acknowledgement, recovery bounds and interaction tests.

## Application detail commands

Application window and desktop-action groups use passive shared `DetailColumnCard`
containers and remain information/commands only, not editable fields. Each
`ApplicationWindowRow` owns its command scope and stable window ID; its list owns
shared column measurements, not command routing by row index. Tab uses the
page's non-highlighted scrolling fallback; PageUp/
PageDown scroll, and Up/Down continue browsing application results. Each window
exposes Focus and a destructive Close (×) directly, in the same two-circle footprint
formerly occupied by Focus/More. `SurfaceActionRow` supplies the shared order:
reduce gaps, then sizes, then omit disabled commands only as needed; enabled
commands wrap at extreme widths instead of entering More. Alt+J remains an
additional keyboard route to all available window and arbitrary desktop actions,
regardless of scroll position. Its menu shares modal shortcut guards, native
traversal and focus restoration; removing or replacing commands closes it rather
than redirecting Enter to a different window. Close keeps all existing revision,
busy and backend guards; rows disappear only on authoritative snapshots, with no
optimistic removal or claimed undo. Full labels and stable daemon IDs are retained.
Compact number-first window rows keep workspace/current-window badges and
acknowledged focus-success checks passive, with full accessible names. No field
stops, row-wide hit targets or selection highlights are added. Long titles and
error/progress text can expand the row; Focus/Close normally use shared 32px command
circles with 16px icons.
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
Disabling session memory cancels queued/editor restoration; re-enabling it within
the same invocation must not steal focus or resume the cancelled transaction.
Media result Enter invokes the selected player's capability-guarded Play/Pause
primary action, retaining list focus and expanded/collapsed state. It never routes
to a different active player or falls back to inspection when playback is disabled
or busy. Right remains the action-free way to expand details.
The Media playback card is information-only: contained square artwork, content
labels, read-only progress and numeric elapsed/remaining/rate follow the inspected
player without gaining focus, pinning a player or invoking transport. Tab continues
directly to the shared Pin to bar switch and Bar controls dropdown. Only explicit
Enter/Tab saves the control-mode draft; acknowledged mode chooses track/seek
controls on the compact bar only. The panel exposes Previous, Next, Rewind 30s
and Forward 30s directly, with independent capability guards and no transport
More menu. Shared header sizing may omit disabled commands only as a last resort.
Playback state uses icons and timing uses numbers, with full accessible descriptions;
there is no persistent shortcut legend or instructional footer. Errors remain text.
Recognition and optional daemon-owned YouTube enrichment change presentation/search
only, never the MPRIS routing or pin ID. Video headers show the channel (otherwise
service/browser identity), with the full title in the passive card. Metadata is
plain text. Late artwork/title/channel updates never save or discard a field draft,
steal focus or become new Tab stops; stale owner/content completions are rejected
by the daemon. Online enrichment is an explicit deployment setting, off by default.
See [Media presentation and shortcut diagnosis](media.md).

Applications' Resources page has five passive integrated microcards: Activity,
Memory, Disk I/O, Network and a full-width Power/energy card with app-data bytes.
Icon/value pairs sit beside bar histories; disk/network values are period totals.
The 2×2 + full-width grid fills the expanded detail viewport without scrolling,
reserving space for the header, bottom tabs, range, time axis and exceptions.
Its shared 30m / 2h / 24h segmented field is the sole editable stop and controls
period totals and history, not current snapshots. Pointer choice remains a local
draft; Enter/Tab saves and requests the new range, Escape or leaving the editor
discards without a history request. Tab/Shift+Tab wrap on that field; cards,
glyphs, bars and statistics never become additional stops or click actions.
PageUp/PageDown retain shared page semantics, with no scroll distance in this
viewport-fitted page. There is no definitions/caveats
panel, Measurement details command, Alt+H disclosure or new chart-inspection key
model. Accessible summaries retain full metric identities and observation data;
unavailable/error/loading states and attribution exceptions stay explicit. See
[resource measurement semantics](application-resources.md) and
`tst_application_resources.qml` for actual key/pointer coverage.

## Missing and arriving content

All chooser list panes use the passive shared `ContentState` through
`ChooserListPane`/`ChooserListBody`/`ResultListFrame`. Domain glyphs identify
settled emptiness; a small search, read-progress or error badge distinguishes
no-match, loading and unavailable states. Off/blocked radios retain their
specific disabled glyphs. Disconnection, mute, pause, DND and zero search results
are not power-off states. Audio currently combines inputs and outputs, so its
empty reason is “No audio devices”; Tray uses its native inventory and never
invents readiness from the bar daemon.

Owners supply explicit read state, not generic mutation/screenshot busy flags.
Read errors remain separate from operation status, and a failure cannot become
successful emptiness when an unrelated command completes. Existing rows and
partial history remain visible during refresh/page append; only zero-row lists
show a centered mark. Shared navigation retains focus as rows arrive and safely
closes unavailable details when the selected result disappears. State changes
must not submit, commit, discard or replay domain writes or active editor drafts.

Clipboard keeps its expanded header, selected-kind actions, tabs and preview
frame mounted during result navigation, including the 65ms read debounce. Loading
and errors belong inside the preview; a pending thumbnail/decode must not be
reported as unavailable. Uncached selections never display the previous entry's
editable content. A revision-keyed, invocation-local LRU serves repeat visits
synchronously, bounded to 12 entries and a 2 MiB serialized UTF-16 payload budget
(not an exact heap/decoded-image limit). It stores acknowledged previews only,
never leases or drafts; failed drafts retain precedence. History changes/gaps,
edits, deletion/wipe, annotation, privacy changes, disconnect and hide invalidate
the cache, and pre-invalidation replies cannot refill it. Private mode disables
cache reads/writes. Nothing is persisted or added to chooser presentation memory.
`tst_clipboard_preview.qml` exercises actual result keys, stable geometry, command
targets, image reply ordering, stale reads, eviction, revision and lifecycle guards;
`tst_clipboard_recovery.qml` retains explicit-save and failed-draft coverage.

`ContentState` is static information, not a result, field, command, pointer target
or Tab stop. It uses semantic `GlyphLabel` rendering with legacy glyph fallback,
an accessible text name, and decorative child glyphs. Its reason uses the status
strip only when no domain message owns it; otherwise the reason remains visible
beside the mark. Failures and blockers always retain visible words. The small
loading cue stops when hidden/inactive and respects reduced motion; collecting
history is passive, not an endless request. Agenda, Todos, forecast, battery and
resource history use the same component inside missing-data sections, without
hiding calendar/input/power controls or valid cached readings.

`tests/qml/tst_content_state.qml` exercises semantic/legacy glyphs, actual key
navigation and save/discard during arrival/refresh/removal, read-state adapters,
radio-off versus absent hardware, failure copy, independent Tray readiness, and
partial section data. Existing domain suites retain paging, reply drafts,
acknowledgement, retry, modal and rollback coverage. See the
[visual proposal](proposals/panel-empty-states.html) for the design rationale.

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

Notifications search uses the native grouped center catalog, including unloaded
retained rows within its documented recent-history scope. Typing issues debounced reads only;
query changes supersede old pages, and F5 refreshes without replaying any
command. Page append and atomic same-query refresh preserve keyed selection,
viewport and app-control editing transactions. Stale cursors retry reads; they must not
merge revisions or resurrect deleted rows. A superseded read's success or error
must not retire a newer read or clear a reply draft. Incomplete refresh pages stay
unpublished on read failure, epoch/revision changes, or loss of permission to
continue history loading. Queued revision events are applied before accepting a
page. `tst_notifications.qml` covers representative ordering/validation cases, actual
search key delivery, cursor recovery and reply/viewport retention.

Wi-Fi busy guards apply to conflicting network mutations, not background reads
or portal browser work. Search, result browsing, QR reading and requesting a
refresh remain available during connection changes. A refresh requested during
activation is deferred; a QR scanned while a mutation is pending is parsed by
the daemon without retaining its passphrase in QML. Joining requires an explicit
rescan after the mutation finishes, never a surprise delayed credential replay.
Screenshot capture is independent of network-operation guards (modal privacy
blocks remain). Link completion does not await an internet probe: the daemon
publishes NetworkManager's passive connectivity verdict separately. Unknown
reachability is not a failed Wi-Fi connection or permission to launch a portal.
Power/profile/connect/disconnect commands retain acknowledgement guards. These
commands do not join Tab traversal. **Alt+K** checks a pending connection using
the daemon's owner-scoped `operation.status`; **Alt+X** requests cancellation,
including after the link becomes active or for a QR-originated operation.
Neither command declares completion before the owned terminal event. Missed
events trigger status recovery; failed reads retire only their own read and stop
automatic retries after three failures. Manual Check status remains available.
The daemon's overall connection deadline requests cancellation without releasing
the mutation guard before the worker acknowledges. `tst_wifi_operations.qml`
covers these guards, recovery and shared commands.

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
header/bar tests cover responsive direct-command sizing and explicit menus rather
than repeating a per-panel size matrix. The
[2026-10-06 test review](reviews/test-pruning-2026-10-06.md) records reduced coverage,
including native End/RTL/vertical matrices, outside-drop and
some restoration/consumer paths. Shared transactions, actual command keys and
domain safety guards remain tested; these reductions do not change or relax the
interaction contract.

The [2026-10-07 Lens maintenance review](reviews/lens-maintenance-2026-10-07.md)
changes no keys or save boundaries. Wi-Fi reuses `TabbedDetailsStack` for its
clipped viewport/footer; profile availability still gates its tabs and Ctrl+Tab
still discards unsaved edits. Resource snapshot descriptors feed one passive
reading adapter: replacements update values, availability and accessible names
without adding fields or interrupting the range draft. Native Wi-Fi tab and
resource-arrival tests cover these shared-layout/data paths.

## Display preview baselines

A display draft captures the daemon's opaque baseline. Preview submits that
baseline with the draft; the daemon rejects stale geometry, modes, topology or
policy before any persistent trial or compositor write. Missing baseline support
disables editing. Local stale hints remain conservative presentation guards, not
authority. Rejection preserves the draft for explicit reload; no automatic replay.

## Submitted Bluetooth profile changes

Saving an audio profile submits one native apply-and-remember request. Selection
changes do not retarget it. Partial persistence failure is reported without
replaying the applied hardware change; disconnects never trigger automatic
retries. The shared choice control still owns its local save/discard transaction.

## Submitted clipboard save-and-paste

When Paste submits a dirty edit, the commit includes the captured paste session.
The daemon saves and prepares that session only after publication succeeds. The
client still acknowledges the existing hidden-session handshake, only for the
same active session; it never retries a saved edit for failed paste preparation.
A new Paste intent arriving after an unrelated save was already submitted still
waits for that save before requesting paste; it cannot amend an in-flight write.
Field-local drafts and Enter/Tab/Escape behavior are unchanged.

## Observed application Close

Close commands target the daemon-captured window identities. Admission and close
IPC dispatch are not completion evidence; the daemon reports closed, still-open
or unknown after bounded observation. Filtered catalogs only update presentation
and cannot infer the outcome. Still-open windows retain focus/save-prompt access.
Cancelling observation never claims the dispatched closes were rolled back.

## Native resource statistics

Resource range selection remains a shared local field transaction. Saved range
queries consume native observed totals, whole-window confidence and per-metric
availability; formatting and graph layout remain local. Missing projections fail
closed. Range identity and finite/nonnegative-value checks still reject stale or
malformed results. Resource cards introduce no additional field stops.

## Native domain projections

Activity day membership and busy-day markers come from the daemon's calendar
projection, including DST and undated todos. Day commands change only selection;
no frontend timestamp classification or extra editable stop is introduced.
`tst_activity_days.qml` covers actual day commands against native membership.

## Battery & Power compact presentation

Overview begins with one deferred Power mode field, displayed as three circular
icon choices (saver / balanced / performance). The shared `SegmentedControl`
retains its session, arrow editing and Enter/Tab save / Escape discard behavior;
its circles are not independent commands or switches. The saved selection dot
is distinct from the draft's tonal highlight. Bottom pages retain shared
icon-only tabs and full accessible names.

Battery care combines charge notification with protection. The bell's numerical
target follows acknowledged protection / one-time-full-charge state. Resume/stop
thresholds remain deferred; separate alert and threshold pending/error state is
retained. One-time charge, pause/resume and calibration use a compact shared
content action row (Alt+O/P/C), outside field traversal. Ordinary success copy
is hidden, not validation, firmware mismatch or operation progress.

Calibration starts only after a shared confirmation; cancelling an active
calibration remains direct. Enabling critical-battery hibernation reviews the
single-manager / working-hibernation requirements; disabling remains direct.
These dialogs block underlying field, command, refresh and tab shortcuts, keep
native modal traversal, and restore prior focus on dismissal. Closing the panel
or changing tabs discards the review; replacing the calibration battery cancels
rather than retargets it. Confirmation rechecks capabilities and busy state.

Routine caveats and source/health/power readings use passive semantic icons with
accessible descriptions. Section Help is a named Alt+J command, not a field stop
or hover tooltip. Automatic-sleep integration failures keep a visible warning,
with the original diagnostic behind Details; independent critical protection
retains its own availability guards. Profile holds, degraded performance,
countdowns and recovery commands remain visible. See [Battery & Power](battery-power.md)
and `tst_battery_presentation.qml` / `tst_battery_suspend.qml`.
