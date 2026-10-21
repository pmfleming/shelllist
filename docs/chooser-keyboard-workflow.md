# Shelllist interaction contract

The current visual roles and deliberate domain exceptions are recorded in
[Panel UI standardization](panel-ui-standardization.md). Shared headings and
messages are passive; Help remains a named command, not an editable field.
Compact toggle rows retain the full 52×32 track and readable passive labels.

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

`FieldRow` owns the common left-label/right-editor composition used by
`FormField`, `SettingRow`, sliders and toggles. Expanding editors retain the shared
label column; fixed-size switches stay right-aligned while their labels and
subtitles use all remaining width. Labels wrap only within that available space;
panels must not introduce stacked labels or private breakpoints.
Inline icons/names, separators, state badges and disclosed help are passive: the contained shared editor keeps its stable focus identity and
transaction. A single-line or expanded scrolling `TextEditor` is still one field.
DNS/legacy IP diagnostics become visible on explicit save without trapping Tab;
their raw full-buffer and CIDR/zone rejection guards remain intact. The shared
`IpField` exception below supports combined address/subnet input and red-only
validation. Saving retains invalid domain drafts, while whole-group readiness
blocks invalid/incomplete backend writes. Neither path may accept a silently
shortened native buffer, including one whose clipped suffix is whitespace.
There is no cross-field paste write or per-keystroke semantic normalization.

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

`LinkedValueSlider` is the shared non-linear, constrained slider composition.
It remains one `LabeledValueSlider` field and uses the same `FieldEditSession`;
its labels, scale endpoints, companion marker and hatching are passive. Both
members of a pair use the same fixed `scaleValues` ruler. Arrows select the next
allowed stop; Home/End select the first/last allowed stop. Pointer mapping uses
that same ruler, including RTL. Limits restrict choices without stretching the
track, swapping endpoints or moving the companion. Incoming peer changes reject
an uncommitted save rather than reinterpret it. An out-of-scale exact source is
shown numerically without a misleading clamped handle or automatic write.

Dragging is the primary pointer interaction; there is no inline edit button or
reserved command gutter. Scoped **Alt+V**, also listed in **Alt+J** for the current
slider, opens the shared exact-value `PromptDialog`. Its presentation-free
`ActionControl` opts into `includeInCommandMenu` despite having an access key;
commands without that opt-in keep their existing menu policy. The value and
labels remain passive, not click-to-edit targets or extra Tab stops.
Opening the exact-value command discards an unsaved slider edit.
The modal uses ordinary required-input traversal and explicit Save/Cancel; typing
never writes. Only integer values satisfying the current domain limits may save.
Sleep exposes **Never** as an explicit modal option, not zero on the numeric
ruler; its integer wire representation remains 0. Source/peer changes block a
stale modal save and loss of availability closes it. Shared `DetailsNavigation`
registers the field-owned modal and temporarily preserves/overrides the host
controller's navigation guard; tab switching, refresh and underlying commands
cannot run through it. Suspension closes it without saving, and dismissal restores
the host's original guard binding. Modal acceptance submits an explicit exact-value
command; it does not add a field Tab stop. Existing backend
acknowledgement, retry and capability guards still own the outcome. Shared field
tests retain commit/rollback; Battery's consumer tests retain atomic timing
translation and retry. Step-size, RTL and per-profile presentation matrices were
retired in the [ownership review](../tests/test-reduction-owners.md).

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

## Structured IP fields

`IpField` is the shared IPv4/IPv6 editor, composed through `FormField`/`FieldRow`
and dispatched by `DetailsNavigation` with one `FieldEditSession`. Configure
`family: "ipv4" | "ipv6"`, `mode: "address" | "addressWithSubnet"`,
`subnetNotation: "prefix" | "netmask"` (netmask is IPv4-only), and domain-owned
`allowEmpty`. Unsupported combinations fail closed. An address-only field has
no subnet component and rejects suffixed paste as a whole. Combined input saves
one address/subnet draft, never two independently discoverable fields. Wi-Fi
uses combined prefix notation for both families and address-only gateways;
DNS lists/search domains retain their existing editors and parsers.

IPv4 has four decimal slots with fixed dots. Three newly entered digits advance
only when filling an empty slot or replacing a selected whole slot. Short octets
use Right at the slot end, a typed dot, or a click. Mid-value corrections do not
spill into neighbouring slots. A combined value continues into its prefix or
four dotted-mask slots; address-only entry ends at the last octet. No automatic
save, guessed short-octet boundaries or range clamping. IPv6 uses native address
text, including hex letters, editable colons, one `::` compression and embedded
IPv4 tails. Colons are never inserted automatically. A combined field has a fixed
slash and decimal prefix; typing slash, Right at the address end or a click enters
that component. Arrows remain internal native editing, not field traversal.
Backspace/Delete preserve fixed IPv4 separators and the structural slash, reaching
the previous/next digit when deleting only a separator. Selection, Home/End,
copy/cut, and bounded field-local undo/redo cover the entire composite. Internal
caret/pointer movement never ends the field transaction.

Enter saves and returns to browsing; Escape discards; Tab/Shift+Tab save and
continue editing with normal wrapping. Even an invalid save returns/continues
without trapping focus. Typing, auto-advance, clipboard/drop insertion, blur and
page closure do not write settings. Configuration or availability changes discard
an active unsubmitted field edit. Incoming snapshots cannot replace it; discard
reveals the latest bound source. Automatic/read-only values stay readable with
the shared lock/Copy composition and never enter editable traversal.

Out-of-range values and malformed allowed-character drafts turn the entire value
red immediately. Otherwise incomplete input stays neutral until explicit save.
There is no visible validation message, error icon or duplicate `FeedbackSource`
contribution for this control. Public validation state and native accessible
invalid descriptions preserve non-colour diagnostics; labels, Help and telemetry
remain passive. This changes presentation, not domain readiness, operational
feedback, capability, acknowledgement, retry or safety ownership.

Full-value paste is atomic: accept configured-family addresses, and in combined
mode accept address/prefix or IPv4 address/dotted-mask. Spaces immediately around
the slash are allowed; other whitespace, scopes, brackets/ports, extra components
and oversized payloads are rejected without replacing the previous draft. A bare
full-address paste clears a previous subnet. Plain numeric/hex substring insertion
is local, never a guessed concatenated IP. Disallowed committed characters cannot
delete the selection. The native buffer does not truncate to an IP-sized limit;
the complete operation is checked before accepting a bounded draft. The parser
also rejects over-limit bound source values. Unrecognized source suffixes cannot
vanish as a side effect of local correction.

Keep raw pasted subnet notation until valid explicit save, including an invalid
non-contiguous mask. Valid save serializes IPv4 octets as decimal, lowercases IPv6
hex without expanding/compressing it, and converts contiguous dotted masks to an
exact prefix (0–32 for IPv4, 0–128 for IPv6). The configured notation is rendered
on save; IPv6 dotted-mask notation is unsupported. Never clear host bits, invent
zeroes/default subnets, strip scopes or convert address families. Optional empty
means the complete field is empty; a half-empty pair is incomplete. `IpCodec`
shares the parser with domain adapters. Wi-Fi retains the whole raw pair in
`IpSettingsState.addressWithSubnet`, so invalid saves continue blocking readiness,
and valid saves cannot publish an intermediate half-updated address/prefix pair.

`tests/qml/tst_ip_control.qml` owns native selection, keyboard/pointer transactions,
clipboard rejection, undo/redo, narrow caret visibility and all five configurations.
`tst_ip_fields.qml` exercises real Wi-Fi saves, both families, gateway rejection,
read-only/family transitions and independent DNS truncation guards. Parser/edit
operations and all IPv4 mask conversions are covered by `check-ip-control.js`;
legacy parser checks remain in `check-ip-validation.js`. Hardware IME, primary
selection/external drag-and-drop, live compositor and human screen-reader checks
remain separate acceptance gates; synthetic/native key tests do not prove them.

## Highlighting

Text carets identify the native editor that currently owns keyboard input, not
an expanded surface or a remembered cursor position. The shared `TextField`
custom caret follows native cursor visibility and active focus, and is hidden
for disabled/read-only inputs. Search retains its query and cursor state when
focus leaves, but its caret is hidden while results, detail browsing, another
editor, a command menu or a modal owns input. Details may remain expanded while
search is focused; search then shows its caret normally. Printable result keys
still transfer focus to search before insertion. Browsing a field shows only its
marker, never an inactive text caret. Returning from save/discard or restoring a
session updates these indicators without changing focus or transaction behavior.
Native caret regressions are covered in `tst_chooser_keyboard.qml` and
`tst_chooser_memory.qml`, alongside shared field transaction tests.

Only the editable portion is highlighted: input box, slider, selected segment or
switch—not the setting's label, explanatory text, row or card. Browsing uses
only a compact opaque Primary marker with a Surface keyline; its background is
transparent. The marker/keyline pair retains at least 3:1 contrast, including over
selected or filled controls. Saved selection, switch-on, hover and pressed paint
retain their independent meanings. This is not a
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
padding and gaps have no action. Native pointer/accessibility routes at
representative wide/narrow sizes live in `tst_media_chip.qml`; its rounded-artwork pixel check additionally
requires an RHI renderer.

The chromatic bar uses fixed-size icon-only category targets (Shell, Browser,
Code, Media, Text for workspaces 1–5), never active-workspace labels or focused-app
icon substitution. Shell uses the shared font-independent `TerminalGlyph`:
a rounded chevron and underscore (`>_`), without a terminal-window frame. It is
passive artwork inside the existing workspace action, not a separate target.
Acknowledged selection paints the accent glyph immediately
at 22px rather than 20px, without a resting tile or separate lower selection mark. Occupancy uses
regular/semibold glyph weight and neutral/muted foregrounds; it is not a disabled
state. Existing static urgency outlines and upper-right marks remain distinct.
These visual changes add no focus targets or new keyboard behaviour.
Workspaces stay left, system status right, and Media is centered when space permits,
clamped between the measured edge groups otherwise. Narrow widths reduce gaps and
omit the numerical date, not actions; below the full strip's minimum width the
existing explicit overflow scrolls it. Workspace overflow still scrolls independently
and reveals the active workspace. Neither layout nor reveal dispatches an action.

Standalone panels initialize keyboard browsing on activation once their visible
content is attached and ready, even if the host's focus request preceded view
creation. First entry selects the first available editable field; reopening
restores the saved field. No initial Tab is required. Late duplicate host requests
must not reset subsequent keyboard/pointer navigation, and closing cancels queued
focus. Presentation records initialized while inactive are created on activation
so the first invocation can remember fields without storing unsaved values.

Battery is one direct action with a continuous bottom-up fill and a reserved,
non-overlapping external state-mark slot. Lightning, plug, check, warning and
unknown marks never cover the fill and do not become independent targets. Invalid
or absent telemetry stays unknown, not a false zero/full value; daemon warning and
critical flags remain authoritative. Only new known fill readings may interpolate
for 160ms, respecting reduced motion. Clock/date form one numerical action opening
Time & Weather, with full date/timezone in its accessible name. The bar adds no
field Tab stops. The standalone dashboard presentation matrix is retired; native
daemon policy tests and shared command/transport owners remain.
System tray application icons appear only in the Tray chooser, opened by the
bar's ellipsis button; no bar density exposes inline tray application icons.
Horizontal sliders place the marker above
the track. Editing replaces the marker with an editor-local tonal background and
lower line, plus native caret/selection feedback; it has no enclosing focus border. Feedback is immediate and never delayed
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
visible in a fixed surface status allocation: provider panels use their existing
list footer; standalone panels use `PanelSurface`'s shared footer. `FeedbackSource`
contributes domain text, summary, tone and priority without taking layout space.
`FeedbackSlot` fits concise owner summaries at the 13px status role, never grows
for paragraphs or shrinks typography. Full diagnostics remain accessible and in
existing domain owners. Safety countdowns and consequences take priority and
retain explicit short wording. Recovery controls retain their geometry and guards.
Only explicitly disclosed Help can expand a supporting row. DNS/other native multiline editors
start at one line and grow to a bounded scrolling area; explicitly sized document
editors retain their size and single-field transaction. See the
[shared FormField implementation](../qml/Shelllist/Ui/FormField.qml) and
the retained `tst_field_interaction.qml` and `tst_ip_fields.qml` transaction suites;
exact composition and paint evidence is reduced as recorded in the pruning review.

Bluetooth’s **Restore original name** is an icon-only trailing action inside the
shared Name text field, not a separate labeled/explanatory row. Its accessible
name and Alt+O command remain available through shared command navigation, never
Tab traversal. The icon retains its geometry when disabled; dirty-name, busy,
missing-original and already-original guards and authoritative acknowledgement
are unchanged. `TextField.trailingAction` exposes the shared embedded command for
identity/access-key configuration. `tst_bluetooth_recovery.qml` covers its actual
pointer/key routes, native save/discard, placement and disabled guards.
The device Name field has no separate Retry rename / Discard draft button row.
Name validation, error feedback and controller-owned failed drafts remain intact;
this does not remove the adapter settings' recovery commands.

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
existing contained native modal traversal. The display-trial dialog opts into
shared inline header actions: Revert sits beside Keep, retaining initial Revert
focus and the same Tab/Enter routes. Its larger centered countdown and compact
card replace the visible instruction paragraph; timeout, stale-state guards and
daemon rollback are unchanged. Ordinary panel headers keep their normal two tiers;
approved compact confirmations also opt into inline actions as documented below.
The shared inline option falls back to those tiers when commands cannot fit. See the
[shared action row](../qml/Shelllist/Ui/SurfaceActionRow.qml).

- Action buttons normally use **Alt+letter**, not Tab. `ActionControl.accessKey`
  defines a command; explicitly approved Ctrl commands (currently Bluetooth
  **Ctrl+N**) use `accessModifier: "Ctrl"` in the same registry, never a parallel
  panel-local shortcut. `commandScope` can limit a repeated command to the current
  field/row (e.g. Alt+H for its help). Duplicate active chords fail closed.
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
250ms; holding Ctrl shows the detail-tab chord and any explicit Ctrl command
badges. Ctrl commands never appear among Alt hints. AltGr does not show hints.
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
Up/Down still select application results. `DetailListView` owns keyed viewport
capture and bounded offset restoration beside its scroll memory. Notification
publication brackets that shared operation; it does not keep a second viewport
state. Pointer movement, PageUp/PageDown and hiding cancel queued anchoring so
late layout work cannot undo newer navigation. Missing anchors retire safely.

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
guards. The notification backend consumes a completion's request identity and
checks its domain generation before flushing queued observations or acknowledging
any domain. Duplicate/obsolete replies cannot publish, and cancellation replies
cannot clear unrelated errors or apply snapshots. Scoped catalog, policy and
consent owners remain separate from generic action/snapshot completion.
Tab changes still discard only uncommitted app-control edits.
`NotificationCatalog` owns only app-group reads; its obsolete selected-record/page
reader is removed. Timeline and explicit group-resolution replies cannot retire a
catalog read. Native tests cover that ownership boundary and timeline validation.
Dropdown values/options share passive `DropDownLabel` composition; icons and saved
checks retain their existing identities and do not become additional field stops.

Notification history has no Retry row or Alt+T command. Read failures use shared
surface-owned `FeedbackSource` contributions in the fixed list status bar, also
on App controls and with details collapsed. Cached rows remain; Refresh/F5 starts
another read without replaying mutations. Bounded read contention recovery and
read deadlines belong to `bar-daemon`; the frontend retains transport, ownership
and stale-window guards, not a storage retry loop.

Native windows stage refreshes atomically and fence stale revisions, epochs,
queries, period changes and local-midnight rollover. The center's pure row
projection preserves validated native order and member identities; it must not
infer periods, initiate reads or add field stops. Frontend notification readers
share wire-shape validation, not request ownership or publication. Timeline
continuations keep accumulated entries and metadata in one unpublished window;
an owned completion consumes that window once and only a validated continuation
can stage it again. Unowned replies cannot retire its busy state or discard it.
Malformed previews, periods or stack members retain the published window and
surface an error, never a partial replacement. Delete-count validation retains its separate bounds and no-replay
policy. `tst_notification_center.qml` covers these rejection/continuation paths. Recent previews and period
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
leaves a passive crossed-window icon (accessible name “No open windows”) with
Launch available. Missing desktop actions use a passive crossed-extension icon
centered lower, below App data; neither empty-state mark joins field traversal. Conflicting commands are blocked
per application, not by freezing result navigation. Initiation, progress and
confirmed completion use the fixed list status bar, including collapsed details
and all detail tabs. There is no Check status row/button or Alt+K command;
read-only recovery is automatic and status text is not a field stop. A
missing/malformed status reply retires only its owned read so bounded automatic
recovery can continue, never replaying the mutation or announcing completion. A removed window command
returns to shared detail browsing. Closing a view does not cancel its submitted
operation, and a late reply cannot dismiss a reopened or newly browsed view.
Background errors notify without reopening. Active progress and terminal outcomes
share the same ownership gate. Terminal launch placement warnings prevent a new
handoff; Close never hands off, even with unrelated launch/placement metadata.
Missing Close observations remain unconfirmed, not successful window removal.
See [application action outcomes](application-actions.md) for ownership,
acknowledgement, recovery bounds and interaction tests.

## Application detail commands

The Applications header exposes only Focus/Launch, New tile and Close all windows;
there is no header More menu or Alt+M route. Individual-window and desktop-defined
commands belong only to the Application tab, including its shared Alt+J content
menu. Switching to Resources or Settings removes those page-local commands without
changing submitted operations, backend guards or the remaining header shortcuts.
One asynchronous loader instantiates only the selected application detail page;
page replacement still discards an unsaved field without submitting it. The native
application journey opens Settings through the real panel; the separate page-cycle
and page-replacement matrix is retired.

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
stops, row-wide hit targets or selection highlights are added. Long
titles can wrap, but error/progress text uses the fixed surface footer rather than
expanding rows. Focus/Close normally use shared 32px command
circles with 16px icons.
See [application details](application-details.md) for the visual and capability
contract and Qt interaction coverage.

## Updates review

Updates uses the shared ProviderChooserSurface and a real native Tray entry.
Up/Down browse recorded runs; Enter/Right inspect without executing an update.
Alt+V reads the selected run's bounded worker journal or private rebuild log; Alt+C copies its recorded
summary and Alt+A returns to all recent runs. Read-only details use the shared
scrolling fallback, not editable field stops. F5 only refreshes reads. Incoming
runs preserve stable selection; malformed, stale or closed-view replies cannot
replace published rows. Live notification deep links target a validated run ID;
missing runs return to history with a notice, never open an unrelated run.
Passive local-calendar date headers do not join result or field navigation;
Up/Down still moves directly between runs in catalog order. Relative timestamps
and live duration update without requests, selection changes or focus movement.
Partial-history warnings preserve readable rows; log loading/errors stay inside
the selected run's log card and never replace the history empty-state reason.
History coverage appears once in the list footer, not as a detail field.
The generic Tray chooser keeps its inspect-first behavior and explicit Activate
application command. No inline tray icon or privileged update control is added.
See [Updates](updates.md) and `tst_updates.qml`.

## Implementing or extending a panel

1. Use `ProviderChooserSurface` or `PanelSurface`; their shared keyboard
   workflow is mandatory, not an optional migration mode. Do not add local
   Up/Down field traversal or Right-to-edit.
2. Use shared `TextField`, `TextEditor`, `IpField`, `DropDownList`, `SegmentedControl`,
   `ValueSlider`/`LabeledValueSlider`/`LinkedValueSlider`, `ToggleRow` and `ToggleSwitch` controls.
   Assign stable `objectName`/`focusKey` identities for ordinary restoration.
3. For deferred settings, consume **`edited` / `selected` / `editingFinished`**,
   not `textChanged`, `valueChanged`, native `activated`, or focus loss. These
   public edit signals publish only on save inside a navigation boundary.
   `FieldEditSession` owns only the temporary original/draft transaction; it
   never stores values in presentation memory. Dropdowns and segmented controls
   share its internal `ChoiceEditSession` specialization: the acknowledged source
   stays bound while the session owns the choice draft. Incoming snapshots do not
   replace that draft; Escape or blur reveals the latest source without publishing.
   `tst_field_interaction.qml` exercises both controls with actual native keys. Raw controls outside a panel
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
there is no persistent shortcut legend or instructional footer. The shared list
status bar remains visible with a media icon and player count (matching/total while
filtering); loading, pending operations, unavailable service and errors take
precedence. It is passive, retains fixed geometry and adds no focus stops.
Errors remain text.
Recognition and optional daemon-owned YouTube enrichment change presentation/search
only, never the MPRIS routing or pin ID. Video headers show the channel (otherwise
service/browser identity), with the full title in the passive card. Metadata is
plain text. Late artwork/title/channel updates never save or discard a field draft,
steal focus or become new Tab stops; stale owner/content completions are rejected
by the daemon. Online enrichment is an explicit deployment setting, off by default.
See [Media presentation and shortcut diagnosis](media.md).

Applications' Resources page has five passive history rows on one detail surface:
Activity, Memory, Disk I/O, Network and Power. Compact shared label/value columns
leave the remaining width for disjoint charts; muted metric pairs, swatches,
secondary dashes and direction labels distinguish series. Disk/network readings
are period totals; energy is not a plotted power series. Activity uses lines,
memory retains bucket steps, and transfer/power histories use interval columns.
Missing intervals are never bridged or replaced by zero; gaps in all series have
subtle shading, not repeated text. Identified app-data bytes remain on Application
details. Estimated attribution, observation coverage, confidence and availability
semantics remain authoritative.
Five equal rows fill the viewport, with readable font-measured minimum heights;
short panes scroll through the shared page. A single time axis aligns with the
plots. The redundant visible range label is omitted, not its accessible name.
Its shared 30m / 2h / 24h segmented field is the sole editable stop and controls
period totals and history, not current snapshots. Pointer choice remains a local
draft; Enter/Tab saves and requests the new range, Escape or leaving the editor
discards without a history request. Tab/Shift+Tab wrap on that field; rows,
glyphs, bars and statistics never become additional stops or click actions.
PageUp/PageDown retain shared page semantics and reveal short-page content. There is no definitions/caveats
panel, Measurement details command, Alt+H disclosure or new chart-inspection key
model. Accessible summaries retain full metric identities and observation data;
unavailable/error/loading states and attribution exceptions stay explicit. See
[resource measurement semantics](application-resources.md). Dedicated resource
and application-page matrices are retired. Shared field and native history tests
do not prove every resource-specific pointer/key route.

## Missing and arriving content

All chooser list panes use the passive shared `ContentState` through
`ChooserListPane`/`ChooserListBody`/`ResultListFrame`. Domain glyphs identify
settled emptiness; a small search, read-progress or error badge distinguishes
no-match, loading and unavailable states. Off/blocked radios retain their
specific disabled glyphs. Disconnection, mute, pause, DND and zero search results
are not power-off states. Audio currently combines inputs and outputs, so its
empty reason is “No audio devices”; Tray uses its native inventory and never
invents readiness from the bar daemon.

Shared chooser wrappers expose header/list/status inputs as aliases to their
owning controls, not duplicate mutable forwarding state. Defaults, incoming
bindings and the native refresh guard are unchanged. Result-edge fades share
one passive delegate; they never join field or command traversal.

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

The standalone ContentState presentation matrix is retired. Retained domain
journeys cover representative paging, draft/retry, modal and rollback behavior,
not every arrival/removal adapter permutation. See the
[shared ContentState implementation](../qml/Shelllist/Ui/ContentState.qml) for the current presentation.

## Validation

The [current pruning review](../tests/test-pruning-current.md), measured from
clean `c4bd285`, reduces the established inventory **441 → 295** without changing
this interaction contract.
Shared field transactions, native domain acknowledgement/recovery and representative
destructive/failure paths remain. Repeated command/error/reconnect combinations,
per-surface startup/shortcut routes, compatibility-only APIs, exact geometry/paint
and presentation permutations have less direct evidence; the review names those
gaps and retained owners. Earlier test
coverage statements in this document describe their original checkpoints, not a
promise that every historical scenario is still a separate test. No new skips,
discovery exclusions or counter changes were introduced.

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

The display layout diagram and arrangement controls appear only on **Settings**.
Their group stays content-sized: when placement controls are unavailable (for
example, only one display is enabled), it cannot consume the settings viewport.
Content, resolution, refresh, scale and orientation retain their scrolling area.
**Information** reclaims their entire vertical allocation; hidden arrangement
commands and the reference field are unavailable there. Tab changes preserve the
saved layout draft, and dirty/error feedback stays in the status bar on either page.
Display arrangement guidance and disabled/mirror blockers contribute once to the
fixed list status bar on Settings, not labels below the map or settings. The routine drag hint
is shown only when arrangement is available and no dirty layout or operation status
needs attention. Full mirror consequences and blocked-direction diagnostics remain
accessible there; feedback adds no field stops or inspector height. Display pages
have no inline reset command or reserved reset row. Leaving a dirty layout retains
the existing Discard / Keep editing confirmation; global settings keeps its Back
command and row. Removing that row never hides dirty/error status from the footer.

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
historical 2026-10-06 test review (retired from the checkout) records reduced coverage,
including native End/RTL/vertical matrices, outside-drop and
some restoration/consumer paths. Shared transactions, actual command keys and
domain safety guards remain tested; these reductions do not change or relax the
interaction contract.

The historical 2026-10-07 Lens maintenance review (retired from the checkout)
changes no keys or save boundaries. Wi-Fi reuses `TabbedDetailsStack` for its
clipped viewport/footer; profile availability still gates its tabs and Ctrl+Tab
still discards unsaved edits. Resource snapshot descriptors feed one passive
reading adapter: replacements update values, availability and accessible names
without adding fields or interrupting the range draft. Native Wi-Fi tab and
resource-arrival tests cover these shared-layout/data paths.

The [2026-10-07 test review](reviews/test-pruning-2026-10-07.md) reduces the
established inventory from 464 to 311 units without changing this contract.
It preserves shared field transactions, actual domain commands, acknowledgement,
retry, secret handling, malformed/late replies and no-replay guards. Exact
presentation matrices, old identity aliases, per-wrapper geometry, some happy-path
restoration and consumer wiring receive less direct coverage; the review names
those gaps. Shared tests do not prove every consumer route. The existing RHI-only
media pixel skip remains counted but is not passing coverage on the software
runner; no new skips or discovery exclusions were added.

## Display preview baselines

A display draft captures the daemon's opaque baseline. Preview submits that
baseline with the draft; the daemon rejects stale geometry, modes, topology or
policy before any persistent trial or compositor write. Missing baseline support
disables editing. Local stale hints remain conservative presentation guards, not
authority. Rejection preserves the draft for explicit reload; no automatic replay.

## Display settings state and modification

Display layout fields show the current observation or the explicitly saved local
layout draft; only Preview/Keep applies that draft. While a policy acknowledgement
retires a baseline, fields fall back to observation, never fabricated defaults.
Information and result rows continue to describe observed outputs.

Docking shows **Manual layout · Laptop on/off** when the daemon reports a manual
enablement override. The manual entry is passive current state, not an editable
policy value. Choosing and saving either docking preference resumes automatic
control, including the previously saved preference. Escape discards the choice;
no write occurs on selection alone. Pending/error/trial guards and the native
fallback remain intact. A docking acknowledgement clears the override immediately,
without claiming that hardware already changed. Daemon `docking_state: applying`
keeps layout fields, On/Off, Preview and further docking saves unavailable until
observed `settled` or explicit `failed`; an acknowledgement alone cannot reopen
these controls. The final observation supplies the next editable baseline. Failed
shows a passive current-state option so selecting even the same stored policy and
saving explicitly retries it; manual recovery still requires Preview/Keep. There
is no QML delay or automatic retry. Native last-screen/unplug fallback is unchanged.
Unknown policy is unavailable; layout-baseline availability does not gate docking,
and independent focus settings do not wait for docking hardware completion.

Focus choices and numbers retain field-local edits across incoming observations.
After a valid save, passive values stay acknowledged until an authoritative update;
failures do not leave proposed numbers masquerading as current settings. Invalid
numbers remain available for correction. Dropdown native indices follow their
shared choice draft, not a panel-local binding. These controls retain ordinary
Enter/Tab save, Escape discard, and no-write-on-blur behavior. See `tst_displays.qml`
for actual keyboard/pointer, state-arrival, retry and capability-boundary tests.

## Bluetooth battery connection and readiness

Component artwork and its connected badge follow the device's acknowledged
connection, independently of battery availability. An unknown percentage never
fills a battery ring or implies a low battery. While connected and explicitly
`services_resolved: false`, missing reading slots show a passive refresh cue:
“Waiting for battery details: Bluetooth services unresolved.” This describes a
readiness wait, not an active Fast Pair retry or guaranteed component support.
Each reported reading replaces its own cue; existing aggregate/component readings
remain visible. Resolved-but-unreported values, missing readiness metadata and
disconnected unknowns show a dash, not endless progress. Remembered disconnected
values retain their existing presentation.

The cue stops animating on inactive/hidden pages and respects reduced motion
with a static symbol. It adds no focus stops, commands or backend requests;
connection badges refer to the whole device, not independent case/earbud links.
`tst_bluetooth_recovery.qml` covers two/three-component snapshot transitions,
partial/zero readings, unknowns, hidden/inactive pages and transport loss.

## Bluetooth noise-control tray

Clicking the existing noise-control artwork or invoking the secondary **Noise
control (Ctrl+N)** command opens the same image tray across the battery row. The
tray slides in from right to left and back out to the right on dismissal, clipped
to that row's existing bounds. It adds no card, height change or movement of Audio
or the footer; reduced motion skips the slide. On a narrow inspector its choices
scroll horizontally. From another detail tab, the command opens Device; if
necessary, the existing page scroller reveals the battery row. It does not resize
or rearrange content.

This is a command-owned menu, not an editable field. Neither the artwork nor the
secondary command is a field Tab stop. The shared `ActionMenu` owns focus return,
modal outside/Escape dismissal and menu navigation. There is no close button.
Left/Right (also Up/Down) and Tab/Shift+Tab browse enabled choices; Enter/Space or
an option click sets the candidate and closes. Escape or an outside click closes
without setting. Browsing never writes. The device-reported mode's icon is bright;
inactive icons are faded. There are no selection boxes or visible Active labels.
A focused candidate has an underlined label, independently of device-state
brightness; accessible checked/active semantics remain intact. Other commands,
refresh and detail-tab shortcuts are blocked through the entire closing animation.
Repeated activation during a transition cannot submit twice.

Alt+O remains **Use as output** in Audio; it does not open noise control. Alt+C
remains **Connect** for disconnected devices. Noise control's Ctrl+N command is
only visible for connected devices advertising ANC.

Only reported modes are listed; modes not currently settable stay visible but
are disabled. A selection closes the tray and submits one capability-guarded
`set-noise-control` operation with a captured device key. The current mode is a
no-op. Busy requests/operations block duplicate submissions, and the hero changes
only when a provider snapshot reports the mode—not on request acceptance. Failures
use the existing Bluetooth operation/status feedback; there is no automatic retry.
Version-1 unsigned ANC needs neither account-key setup nor an authenticated-control
flag in the UI. Disconnect, selection/tab changes, modal prompts, lost capabilities
and UI suspension discard an unsubmitted chooser without retargeting its action.
`tst_bluetooth_noise_control.qml` exercises real pointer/Ctrl+N input, modifier
badges, animated and reduced-motion dismissal, stable Audio geometry, modal
shortcut blocking, focus return, disabled choices, request versus snapshot
acknowledgement, failure and stale-context guards.

## Bluetooth signal telemetry

Signal readings are passive row/detail information, never fields or commands.
Live connected-link readings can replace discovery readings without changing
selection, focus or an active field draft. Cached fallback readings stay dimmed.
BR/EDR connected RSSI is shown in relative dB, not as a fabricated percentage or
absolute-strength bars; LE/discovery readings retain the existing percentage.
These updates add no Tab stops or keyboard behavior.

## Submitted Bluetooth profile changes

Saving an audio profile submits one native apply-and-remember request. Selection
changes do not retarget it. Partial persistence failure is reported without
replaying the applied hardware change; disconnects never trigger automatic
retries. Profile completion publishes only its final acknowledged/partial/unknown
message, not an intermediate success. The shared choice control still owns its
local save/discard transaction.

## Submitted Bluetooth adapter settings

Saving adapter fields submits one native patch containing only already-saved name
and timeout values. Field-local buffers never enter that patch before Enter/Tab;
Escape remains discard. The captured adapter identity and submitted values survive
selection changes or editor unload without a frontend continuation loop. Native
per-field acknowledgements clear only applied values; unknown/not-attempted fields
remain with explicit recovery feedback. A failed snapshot cannot erase a known
write acknowledgement. The adapter edit owner consumes the captured request key
before applying acknowledgement and any subsequent snapshot; duplicate replies
cannot reapply those observations. No automatic replay after disconnect, malformed reply or
partial failure; saving another field cannot silently retry uncertain fields.
Explicit Retry resubmits retained saved values, while Discard only removes local
drafts, never claiming native rollback. Recovery commands stay outside Tab order.
`tst_bluetooth_recovery.qml` covers actual Enter/Tab/Escape, captured identity,
unloaded editors, partial outcomes, malformed replies and transport loss.

## Compact confirmation presentation

The approved confirmation target is Clipboard's single-entry dialog: question
icon, one short question, then Cancel immediately left of Approve at the right
of the same header. No consequence paragraph, repeated action summary or button
captions. The existing compact keyboard hint remains. Shared
`ModalFrame.compactPresentation` keeps `detail` in `Accessible.description`
without displaying it, enables inline header actions and wraps long questions
at normal text size. `PromptDialog` suppresses its action summary in this mode;
`ConfirmationDialog` opts in by default. Existing narrow action-row fallback
and contained modal scrolling remain available; ordinary panel headers still
elide and ordinary prompts retain their presentation unless explicitly opted in.

Clipboard single/selected/history deletion, native notification record/app/global
deletion, Bluetooth Forget and pairing, Wi-Fi Forget, Battery calibration/critical
protection, and Display draft discard use this shared composition. Notification
questions retain the actual snapshot count and scope with correct singular copy.
The existing display trial already matches: Revert/Keep and its countdown are
unchanged. Clipboard's scope chooser, ordinary Wi-Fi credential/QR forms and
Applications' passive empty-state icons are not redesigned.

Required fields and pairing codes are functional content, not explanation.
Bluetooth retains PIN/passkey masking and validation, prominent comparison/remote
codes and entered-digit progress. Display-only pairing has no invented local
accept/reject command or waiting paragraph; the full device/service description
remains accessible. Wi-Fi's challenge is labeled **Type FORGET**; approval stays
disabled until the existing trimmed, case-insensitive challenge is valid. Typing
never submits; controller validation remains authoritative. Password/enterprise
and other credential forms retain their existing noncompact layout.

Cancel receives initial focus for action-only prompts; required-input prompts
focus their editor. Escape cancels and native contained Tab/Return or pointer
activation chooses the action. Display draft discard keeps `enterEnabled: false`
and uses an Undo glyph; its hint describes only Escape, never a new implicit
Enter-to-discard shortcut. Underlying panel field/command shortcuts remain blocked.
These presentation changes do not remove token/challenge expiry, captured request
identity, pending/validation/capability guards, acknowledgement, retry or rollback.
Battery safety prerequisites and destructive consequences stay in accessible
text, not visible explanatory paragraphs.

Clipboard single deletion retains its existing 520px maximum card width. No
smaller fonts/hit targets or new panel-local key model are introduced.
`tst_compact_confirmations.qml` checks actual native focus/keys, normal/narrow
light/dark layout, Bluetooth pairing/Forget and Wi-Fi challenge/credential routes.
`tst_clipboard_recovery`, `tst_notification_center`, `tst_battery_presentation` and
`tst_displays` retain actual consumer cancel/confirm, native IDs/tokens, modal
blocking, policy guards, draft-only discard and display rollback coverage.

## Clipboard pins

Double-clicking a clipboard result's leading icon toggles Pin/Unpin, never
Paste/Copy. Single-click still selects the result; double-clicking the rest of
its body retains the primary action. Expanded details expose the same Pin to top /
Unpin secondary command with **Alt+N**, outside editable Tab traversal and on both
tabs. The command uses a pin icon to pin and a crossed-out pin to unpin.
Multiple entries may be pinned. The daemon persists favorites and returns
them before ordinary history; QML retains that order, including during paging,
and displays an acknowledged, desaturated pin badge at the avatar's bottom-right
corner, not a Pinned text column. Shared `ResultRow` owns its quarter-avatar sizing
and neutral backing; the mark is passive and adds no hit target or Tab stop.
The result's accessible name retains “Pinned”. No optimistic reorder or automatic
mutation retry is introduced. Busy, modal, multi-selection and active edit-lease
guards apply to both routes; failure preserves the existing pin state. Native
`tst_clipboard_pins.qml` covers pointer/key routes, guards and acknowledged ordering.

## Clipboard text saves and recovery

Clipboard has no Retry save / Discard draft button row or recovery shortcuts.
Its shared text editor uses Enter/Tab/Shift+Tab to save and Escape to discard;
Tab continues ordinary editable-field traversal. Save acknowledgement and failures
are reported in the list status bar; errors remain available across detail tabs
and collapsed details. Pending is not success.

A failed save retains the submitted draft without automatic replay. Re-entering
that editor and saving explicitly retries with a fresh lease for the original
revision, preserving conflict and busy guards. Discarding that reopened editor
abandons the failed local draft and reloads the acknowledged value; it never
claims to roll back a submitted backend write. Merely browsing elsewhere after
a failure still retains its draft. Submitted commits capture the same canonical
edit snapshot used for failed drafts, separately from paste intent. A shared
captured-target check routes both success and failure after the editor moves on:
acknowledgement retires only that entry's failed draft, while uncertainty retains
its original revision/value for explicit retry, without replacing the newly
browsed preview. Clearing the view does not clear the captured commit.
`tst_clipboard_recovery.qml` covers native Enter/Tab/Shift+Tab/Escape, result-key
navigation during a save, status feedback, fresh-lease retries and conflicts.

## Submitted clipboard save-and-paste

When Paste submits a dirty edit, the commit includes the captured paste session.
The daemon saves and prepares that session only after publication succeeds. The
client still acknowledges the existing hidden-session handshake, only for the
same active session; it never retries a saved edit for failed paste preparation.
A new Paste intent arriving after an unrelated save was already submitted still
waits for that save before requesting paste; it cannot amend an in-flight write.
The native hidden-session handshake is separate from save completion: missing,
failed, mismatched or stale paste outcomes cannot issue a fallback publication
or repeat the commit. Paste intent never becomes retained failed-draft state.
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

## Wi-Fi credential acknowledgement

Required credential dialogs submit through either native Enter or their primary
command. Answering an outstanding SecretAgent request is allowed during the
connection that requested it. The form remains open, with repeat submission
blocked, until its matching acknowledgement. Failed dispatch preserves the draft;
expired/unavailable requests clear secrets and require an explicit new connection.
A late cancellation or reply cannot close another request's form. NetworkManager
persistence is separate from credential acceptance and link activation. Forms also
honor the daemon's advertised remaining deadline and clear drafts on expiry.

Ordinary Connect activates a saved profile without an initial password form; only
NetworkManager's live SecretAgent request collects credentials. Terminal failures
show native status/recovery text rather than opening another form automatically.
Saved personal-password profiles are edited through Password on the
**Security & privacy** tab. There is no header key button or Alt+U command.
Opening the tab neither reveals nor updates a password and does not reconnect;
the versioned editor retains its deferred field transactions.

Password's eye command retains native editor focus, toggles an existing local
value without replacing it, and requests the saved secret only for an empty
field. A successful read rebases an unchanged empty transaction without saving;
a replacement typed while the read is pending is retained. Repeated identical
replies still reveal after a profile reload. Failed/unavailable reads retain the
error and explicit retry. Shared TextField embedded actions keep focus in their
editor rather than discarding its draft. `tst_wifi_operations.qml` exercises the
eye clicks, repeated reveal, pending reads and no-write boundaries, and verifies
that the removed header command and Alt+U shortcut remain unavailable.

Remember network defaults on for each new connection intent. The disconnected
network's profile card, password/hidden/enterprise forms and Qrca's scanned-network
confirmation expose an explicit opt-out. Opt-out creates a volatile,
non-autoconnecting profile without updating an existing saved identity; it does
not delete an earlier saved network (use Forget for that). SecretAgent requests
marked NOT_SAVED never offer saving. A system-owned SecretAgent request keeps
Remember checked and unavailable: omitting a deferred save cannot prevent NM
from persisting its reply. One-time use requires cancelling and starting a separate
temporary connection; the saved profile and its password remain unchanged. An old
backend without retention metadata likewise cannot offer a trustworthy native
use-once toggle. Mixed system/agent ownership blocks submission and directs the
user to explicit migration or a separate temporary connection; it cannot offer
an impossible save choice. Neither behavior deletes an existing profile. Only explicit NM
disk-write confirmation reports stored; a failed confirmation does not imply that
native activation failed or prove that no password reached disk.

Qrca retains its scanned-network Remember control but delegates connection to
nm-daemon's `wifi.qr.connect` through the JSONL client. It never independently
rewrites a saved profile. The password stays off process arguments, completion
requires the matching terminal event, and transport failure never replays a
connection. A failure to observe completion directs the user to Wi-Fi settings;
receiving the request is not connection success.

## Native Wi-Fi prompt descriptors

Hidden-network fields, defaults, security mappings and conditional required fields
come from nm-daemon's status descriptor. Missing descriptors disable opening that
form rather than inventing choices. Credential requests use native SecretAgent
field descriptors, not frontend interpretation of failure-reason strings. Native
recovery descriptors remain advisory status text after failure; they never start
another credential transaction automatically. Labels, focus,
shared field drafts and cancel/save behavior remain frontend-owned; backend
credential and connection validation remains authoritative.

## Native time/weather locations

Home is protected Amsterdam. Its passive house icon and Current's target icon
identify roles, not actions. When the native effective location is in Amsterdam's
canonical timezone, only Home is presented: no separate Current row, Current icon,
Current label or estimate metadata on Home. Home's fixed coordinates and forecast
never become the estimate. There is at most one populated Current row away from
Home. Unknown/unusable location has no blank placeholder; retain the last accepted
place during acquisition and never invent a location from a timezone alone. Equal UTC
offsets alone do not establish Home. Selection hands off from a disappearing
Current to Home where the current query permits, and reappearance never steals it.

All city headers and both tabs share one Manual-location primary (Alt+L), then
Return to Automatic (Alt+R) and Remove (Alt+D) secondaries. Protected/unavailable
commands retain shared geometry. List Enter still only opens details. Add uses
the existing search trailing plus (Alt+Enter from search, or Alt+A). Commands also
work through shared navigation while collapsed; no city-row action gutter or new
field stops are introduced. Manual/Automatic act on location policy, not Home.

Add and Manual use shared `SearchChoiceDialog` with one `SearchChoiceField`, not
separate search and City selectors. Its shared `FormField` label stays left of the
native editor. Typing requests bounded, debounced native search reads. Down opens
and browses suggestions; Up browses back; Enter or an option click chooses a local
candidate without submitting. Left/Right, selection, Home/End and IME input remain
native text editing. Escape first closes suggestions, then cancels the modal.
Tab/Shift+Tab traverse the single editor and explicit modal commands; neither the
embedded dropdown arrow nor suggestions become extra field stops. Replacement
results clear an old highlight instead of silently choosing a different city.
The modal has the Add/Manual identity glyph and Cancel immediately left of Confirm
in the shared inline header; there is no repeated action-summary footer.
`ChoicePopup` and `DropDownOptionDelegate` share the ordinary dropdown composition.
Submission captures identity/revision and awaits native acknowledgement. Only a
nonempty owned reply ID may retire a search, status read or mutation; empty,
unowned and duplicate replies cannot change the current picker or its diagnostics.
Invalid city acknowledgements retain the published catalog and the open picker.
Escape cancels the unsubmitted choice; closing a submitted dialog does not undo or
replay its command.
Remove uses shared compact confirmation, initially focused on Cancel. Modals block
underlying commands/refresh/tabs. Native safety/authorization remains authoritative;
old or absent authority support leaves controls unavailable without shell fallbacks.
`tst_time_weather_locations.qml` exercises actual pointer/key routes, same-header
geometry, Home/Current roles, modal isolation and acknowledgement boundaries.

Location IDs and cross-source merging come from bar-daemon. The client retains
locale sorting, filtering, focus and selection; list rebuilds retain the previous
native ID even when labels or ordering change. Browsing arrows and detail-entry
commands continue through the shared chooser surface. The accepted Current location
row keeps its stable ID; a known manually selected place supplies its city name,
while automatic estimates retain the generic title rather than inventing a city.
Its passive list/detail subtitle describes
IP/non-IP/unknown provenance and optional **reported** accuracy. This is an estimate,
not a verified physical position or guaranteed radius. Metadata changes do not
select another row, create editable stops, or publish settings. Shared label/header
composition retains full accessible text when the subtitle elides. Passive
metadata/theme/navigation matrices are retired; retained location tests focus
on acknowledged manual selection and protected removal.
List and detail times share a single view-owned clock: activation refreshes it
immediately, then it refreshes at minute boundaries while active. Clock updates
are passive and local; they do not rebuild selection, add stops or issue reads.
City clock metadata is computed from IANA zones independently of forecasts. A
weather failure does not disable a known clock; a missing/invalid zone is
unavailable, never guessed as UTC. Unavailable time/date and map highlights stay
passive, retain location identity and do not introduce editable stops or requests.

## Native domain projections

Activity day membership and busy-day markers come from the daemon's calendar
projection, including DST and undated todos. Day commands change only selection;
no frontend timestamp classification or extra editable stop is introduced.
`tst_activity_days.qml` covers actual day commands against native membership.

## Battery & Power compact presentation

Overview begins with one deferred Power mode field, displayed as three circular
icon choices (leaf / balance scales / speedometer for saver / balanced /
performance), with distinct desaturated sage / blue-grey / sand glyphs and
darker light-theme variants, rather than near-neutral foreground blends.
Colour is supplemental; accessible names, the saved dot and
draft highlight retain their meanings. The shared `SegmentedControl`
retains its session, arrow editing and Enter/Tab save / Escape discard behavior;
its circles are not independent commands or switches. The saved selection dot
is distinct from the draft's tonal highlight. Bottom pages retain shared
icon-only tabs and full accessible names.

Battery history uses two aligned passive tracks: charge in percent above signed
battery power in watts. Dusty blue identifies charge (semantic warning colour
still takes precedence), sage charging above zero, and amber discharging below
zero, with readable light-theme variants. Short text legends and in/out labels
supplement colour. Both tracks retain the observed-time axis and missing-sample
gaps; only charge receives a dotted forecast. Current watts, direction and
zero-versus-unavailable remain explicit. The observed-time caveat and hover/inspection
readings use the shared fixed status bar, not a footer inside the history card;
operation feedback takes priority and hidden history contributes nothing.
Hover shows the nearest measurement;
clicking either track enters the existing pointer-only inspection, with arrows
and Escape inside that mode. Neither track joins Tab traversal or adds an entry
command. The shared Range field retains deferred Enter/Tab save and Escape
discard. Battery history presentation, signed-power and Canvas/inspection
matrices are retired; shared field tests are not a claim of that removed consumer
coverage. Native safety policy, authorization and restoration tests remain.

Battery care combines charge notification with protection. The bell's numerical
target follows acknowledged protection / one-time-full-charge state. Resume/stop
thresholds remain deferred; separate alert and threshold pending/error state is
retained. Lock & suspend commands use low-chroma sand/sage/blue-grey/lavender
glyphs, with Keep awake's acknowledged active fill unchanged. The separate Retry
button and Alt+T shortcut are removed; existing explicit commands and their guards
remain, and sleep pending/error/unknown feedback stays in the fixed footer.
One-time charge, pause/resume and calibration use a compact shared
content action row (Alt+O/P/C), outside field traversal. Ordinary success copy
is hidden, not validation, firmware mismatch or operation progress.

Calibration starts only after a shared confirmation; cancelling an active
calibration remains direct. Enabling critical-battery hibernation reviews the
single-manager / working-hibernation requirements; disabling remains direct.
These dialogs block underlying field, command, refresh and tab shortcuts, keep
native modal traversal, and restore prior focus on dismissal. Closing the panel
or changing tabs discards the review; replacing the calibration battery cancels
rather than retargets it. Confirmation rechecks capabilities and busy state.

Hardware-tuning toggles use passive semantic icons for charging, panel power and
GPU power management, with a tuning-icon fallback for new daemon actions. Their
labels/subtitles expand up to the unchanged switch hit area; icons add no focus
stops or writes.
The Power page separates Lock & suspend, Automatic sleep and Critical protection
into sibling shared task cards, retaining the same controller and safety owners.
“Same settings on battery & AC” names the link switch; passive source headings
show “Battery & plugged in” or both “On battery” / “Plugged in” profiles. The
reported source supplies the passive Current mark; unknown is not guessed.
Suspend at / Hibernate at use total uninterrupted idle minutes on linked,
progressive sliders. Saving Suspend while both timers are finite preserves the
Hibernate endpoint and atomically derives the backend's post-suspend duration.
Saving Never preserves the other duration, including its lid-profile use. With
idle sleep set to Never, Then hibernate instead edits the lid-profile delay;
without that lid action it stays unavailable. Full semantics remain in
accessibility and Help. The docking/wake/low-battery caveat strip is replaced by explicit Help.
Critical threshold/grace fields appear only when enabled; their reveal and profile
linking retain ordinary editable-only traversal. Compact Details / Retry settings
(Alt+R) commands remain outside Tab, with independent diagnostic and saved-failure
guards. Cancel this battery episode retains Alt+C, its full accessible name and
original phase/busy guard. Battery automation and hardware tuning still follow.

Health/power readings use passive semantic icons with accessible descriptions.
Section Help is a named Alt+J command, not a field stop
or hover tooltip. Automatic-sleep integration failures keep a visible warning,
with the original diagnostic behind Details; independent critical protection
retains its own availability guards. Profile holds, degraded performance,
countdowns and recovery commands remain visible. See [Battery & Power](battery-power.md)
and `tst_battery_presentation.qml` / `tst_battery_suspend.qml`.
