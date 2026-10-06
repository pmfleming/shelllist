# Application details: capability-driven Material presentation

Implements the approved [HTML review](proposals/application-details-m3.html),
with the [compact number-first window rows](proposals/window-metadata-icons.html)
revision. The screenshot's browser is an example, not an application-specific layout.

## Presentation

- Retain the shared identity header and primary focus/launch command. Resolve
  the application icon through the theme with a generic fallback. Summarize
  open-window count, not-running state or shortcut behavior in the subtitle.
- Group **Open windows** in one opaque Surface Container with 16px corners and
  subtle separators, rather than individually outlined selection-like cards.
  Use one compact row: workspace capsule, full title, optional focus-success
  check, then Focus/More commands. Single-line rows are 56px at scale 1 (plus
  separators); long titles and named workspaces wrap without clipping.
  Workspace numbers omit the repeated “Workspace” prefix; named workspaces
  retain their names and unknown locations show “?”. A shared location column
  keeps titles aligned, reserving space for the current-window marker.
  The capsule's `center_focus_strong` glyph and tonal fill follow daemon focus,
  not keyboard selection. Full workspace/current-window accessible names remain.
- Only an acknowledged, completed **focus-window** operation becomes a passive
  check beside that window's title. Use structured operation status, never parse
  message text. Preserve the original message as the check's accessible name
  and its existing feedback lifetime. Pending, failed, cancelled, uncertain and
  close/launch outcomes remain readable text below the title. A new operation
  supersedes the old check; success never fabricates compositor focus.
- Remove per-window CPU/memory readouts from this page; the existing Resources
  page retains telemetry, attribution and history. Do not infer window-level
  attribution or invent warnings from aggregate values.
- Group desktop-defined actions under **Application actions**, preserving each
  localized name and identifier. Resolve supplied desktop icon assets; use a
  known Material symbol or neutral `open_in_new` fallback when absent. Do not
  classify actions by localized labels, executable name or browser assumptions.
  Shared `ActionButton`/`LabeledAction` accept an optional `iconSource`, retaining
  glyph fallback, fixed circular geometry and accessible command labels.
- Empty window lists explain Launch; shortcuts explain that content opens in
  another application, without runtime-window claims. Hide empty action groups;
  ordinary desktop applications with none show passive supporting text. Missing
  runtime windows remain explicitly unavailable.
- The existing `DetailFlickable` bounds and scrolls the whole page: no nested
  field traversal, hard cap on window/actions, or extra scrolling region.
  Window Focus/More use shared 32px secondary circles with 16px icons, matching
  expanded headers. Desktop-action geometry and the 56px primary are unchanged.

## Commands and safety

Each window exposes Focus and More. More opens `DetailsNavigation`'s shared
`ActionMenu` restricted to that window's command subtree; its Close command has
no adjacent pointer target. Alt+J retains every window/desktop command even
outside the viewport. Labels, badges and rows remain passive. Command-only
pages use the existing non-highlighted scrolling fallback, not new Tab stops.

The shared contextual-menu entry point (`openCommandMenuFor`) reuses the same
modal guards, native arrows/Tab, Enter and Escape behavior as Alt+J. Removing
the scoped subtree closes the menu. Dispatch resolves the live provider action
by stable window/desktop-action ID, checks availability, and still uses the
provider's revision and backend guards. No frontend mutation acknowledgement,
retry, close-all policy or launch lifecycle is changed by this presentation
work. Existing status/error reporting remains owned by the controller; no
optimistic removal or fictional undo is introduced.

## Validation

`tests/qml/tst_application_details.qml` exercises actual Qt pointer/key delivery:
zero/many windows and desktop actions, launch-only and stale-runtime states,
long labels, page scrolling, editable-only traversal, per-window menu scope,
modal shortcut blocking, Escape focus restoration, arbitrary Alt+J commands,
stable-ID/revision routing, removal while a menu is open and busy guards.
It also checks compact row geometry, aligned titles, passive status clicks,
workspace accessibility, unknown/named workspaces and narrow long-title wrapping.
`tests/qml/tst_application_actions.qml` covers acknowledged versus pending focus,
window-scoped success, localized messages, failure/cancellation, superseding
requests and independence from compositor focus through actual commands/replies.
Shared control and chooser tests cover the reused focus/menu foundations.

The HTML is an offline design study, not a replacement for native tests or a
catalog of installed applications. Hardware compositor, screen-reader and
localized-font acceptance remain separate live checks.
