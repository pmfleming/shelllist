# Chooser keyboard workflow

This is the first step-3 slice of the [Material Expressive plan](proposals/material-expressive.md).
Applications, Bluetooth, Wi-Fi, Clipboard, Displays, Time & Weather, Notifications,
Audio, Media and Tray opt into the shared region/browse/edit boundary. Notifications uses groups as
results and exposes messages/replies in its explicit inspector. Battery and Activity
use the single-panel adapter (Activity keeps Tab within its active overview/details content). Subsequent step-4
slices supply [anchored geometry](chooser-geometry.md) and
[session memory](chooser-session-memory.md): per-result or computer-wide
presentation and ordinary invocation focus, without replaying effects.

## Current keys

- Search is a native text editor. Left/Right move its cursor; Down enters the
  first result. Up from the first result returns to search.
- Printable keys in results, including J/K and spaces, focus search and insert
  at its retained cursor/selection. They no longer invoke result navigation or
  plain-letter detail actions. Command chords remain shortcuts.
- Enter in results runs the primary action; Right explicitly opens and enters
  details. First-time selection is list-only; returning to an inspected result
  restores its remembered view without stealing focus. Right can then resume its
  remembered ordinary editor, while region Tab enters browse mode.
- Outside details, Tab moves between search/results and into already-open
  details; it never opens details implicitly or changes the result selection.
- Once in details, Tab/Shift+Tab cycle enabled content controls in the current
  tab, wrapping last → first / first → last. They leave editing in browse mode,
  without undoing drafts or settings. Header buttons and tab selectors are excluded.
- Enter enters the selected editor; Right remains an alias. Native arrows then
  edit normally. Up/Down also browse without changing settings. Enter/Space
  activate a browsed action button; Space does not toggle a browsed setting.
  Pointer input can edit directly; hover never moves the browse cursor.
- Detail pages also provide a read-only scrolling stop: Up/Down and PageUp/
  PageDown scroll charts/information. Browse targets are revealed in their
  containing scroll view. Tab selectors are excluded from content traversal.
- Ctrl+Tab / Ctrl+Shift+Tab change detail tabs forward/backward and restore content browse focus when invoked
  from details, including asynchronously loaded pages. Invoking it from the
  result region does not steal result focus.
- Escape closes a native menu first, then leaves its editor, then closes details
  and restores results, then dismisses the surface. Left backs out only while
  browsing; text/slider arrows remain native inside editors. Leaving an editor
  does not undo ordinary settings. Domain acknowledgement, debounce and retry
  policies are unchanged.

Expanded `DetailsHeader` actions use Alt+1…9 in displayed order (primary actions
then toolbar actions). Disabled actions retain their number but cannot execute;
closed inspectors, native menus and required-input modals block these shortcuts.
They do not move focus, and their accessible descriptions expose the shortcut.
Other header routes remain: F5 refreshes, Alt+Enter in search invokes its trailing
action, and Ctrl+Shift+S captures Applications, Bluetooth, Battery or Activity.
Activity's Today action uses Ctrl+T; Escape returns to its overview. Bluetooth radio
power and list options remain reachable in its adapter settings, including
when the device list is empty. No help overlay or automatic label was added.

## Shared boundaries

The subsequent geometry slice also routes native focused result delegates through
`ResultNavigation`, just like the list view. Their old local key handlers could
swallow printable spaces, bypass blocked-operation guards or open details without
transferring browse focus. Native delegate regressions now cover that boundary.

`Ui.DetailsNavigation` is a Qt-only focus scope around the existing details
loader. It discovers visible shared input/action boundaries, treats composite
inputs as one browse stop, and excludes headers/tab selectors from the content
sequence. A page with no enabled controls retains a scrolling stop. The separate
browse cursor uses the same immediate rounded tonal highlight as native keyboard
or mouse focus, without an extra rectangular outline; native edit focus and
caret feedback stay with the actual input. Controls
are not disabled merely because the user is browsing.

Busy inputs can lose native Qt focus when their owner disables them. The scope
retains editor ownership and its tonal highlight until the user explicitly
leaves, rather than letting the next Escape accidentally dismiss details.
Removed/hidden editors fall back to content without dispatching an edit. New
content never pulls focus out of another region. The subsequent session-memory
slice remembers ordinary locations by stable control ID, independently of this
live editor ownership. Invocation restoration now resumes the ordinary region and
valid editor/caret, while per-result selection still leaves results/search focused.
New navigation and activation generations fence delayed restoration; Bluetooth
waits for its initial refresh before resuming an editor.

`Ui.ModalFrame` traps conventional forward/reverse Tab among its visible,
enabled inputs/actions and restores valid preceding focus on hide. Native
popup focus is outside that trap. Required-input prompts focus their input;
input-free confirmations focus an action. Surface-level region shortcuts are
disabled while the domain reports a modal prompt.

Bluetooth surface closure now clears all queued pairing credentials and rejects
unsubmitted response-required prompts with credential-free, request-specific
calls. Already-submitted responses retain their original identity and are not
contradicted or duplicated. Closed request IDs are suppressed for the process
lifetime, so late events, failed responses and recovery snapshots cannot reopen
those sensitive prompts. A new request ID can still prompt normally. Cancellation
is best-effort when the transport is unavailable; locally retained credentials
are cleared regardless. Display-only prompts have no response to reject.

## Validation and limits

`tst_chooser_keyboard.qml` exercises actual Qt key delivery, saved query cursor,
contained forward/reverse Tab, Enter-to-edit, guarded header shortcuts, busy acknowledgement, nested menu
Escape, asynchronous Applications tabs/settings, removed editors, read-only
scrolling, and modal focus containment/restoration. It runs with decorative
animations enabled. `tst_bluetooth_recovery.qml` adds the real adapter-settings
journey and sensitive-close/late-response regressions; existing domain recovery
cases remain.

The original slice passed strict lint, **127 behavioral cases / 199 Qt passes including hooks**, runtime
smoke and the full sibling-aware `local-build.py check . --keep-going
--print-build-logs` gate pass. Logs are `/tmp/shelllist-keyboard-validation.log`
and `/tmp/shelllist-keyboard-full-check.log`. The sandbox still prints its
pre-existing Fontconfig default-config diagnostic (also present in the previous
field-slice gate); there are no QML engine warnings or failing/skipped Qt cases.

The contained-Tab/tonal-focus follow-up adds header/modality guards, reverse
Ctrl+Tab, editor-to-browse Tab, mouse/keyboard paint parity and circular workspace
highlight tests. Its current full-suite count is recorded in `tests/README.md`.

Hardware IME, screen-reader and live compositor acceptance remain outstanding.
Later slices extend region navigation and presentation/invocation memory across
the registered domains, including independent Bluetooth adapter records and the
new desktop lists. Production assets and the bar prototype are now delivered;
arbitrary unnamed custom controls still fall back safely. See the proposal's
current ledger and [bar acceptance limits](material-bar.md). No live service
deployment is part of these tests.
