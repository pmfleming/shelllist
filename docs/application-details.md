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
  check, then direct Focus/Close commands. Single-line rows are 56px at scale 1 (plus
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
  Window Focus/Close use `SurfaceActionRow` with shared 32px secondary circles
  and 16px icons, matching expanded headers. Close uses the destructive tone.
  Under width pressure, reduce gaps from 8px to 2px, then circles/icons to 28/14px,
  then omit disabled commands only as needed; enabled commands wrap rather than
  entering More. Widening restores the usual geometry and disabled commands.
  Dimensions scale with `uiScale`. Desktop-action geometry and the 56px primary
  are unchanged.

## Commands and safety

Each window exposes Focus and Close (×) directly; no per-window ellipsis remains.
The pair reuses the former Focus/More footprint. Content-mode `SurfaceActionRow`
keeps stable button identities and joins `DetailsNavigation`'s content-command
registry, without duplicate header registrations. Alt+J remains an additional
keyboard route to every available window/desktop command even outside the viewport.
Labels, badges and rows remain passive; neither button is a field Tab stop.
Command-only pages retain the existing non-highlighted scrolling fallback.

The shared Alt+J menu retains modal guards, native arrows/Tab, Enter, Escape and
focus restoration. Removing or replacing commands closes the open menu rather
than redirecting Enter to another window. Both pointer and menu dispatch resolve
the live provider action by stable window/desktop-action ID, check availability,
and retain the provider's revision and backend guards. Close does not dismiss the
chooser or remove a row before an authoritative snapshot; failures retain readable
status and allow explicit retry. Acknowledgement, close-all policy and launch
lifecycle are unchanged; no optimistic removal or fictional undo is introduced.

## Validation

`tests/qml/tst_application_details.qml` exercises actual Qt pointer/key delivery:
zero/many windows and desktop actions, launch-only and stale-runtime states,
long labels, page scrolling, editable-only traversal, direct Focus/Close commands,
modal shortcut blocking, Escape focus restoration, arbitrary Alt+J commands,
stable-ID/revision routing, removal while a menu is open and busy guards.
It also checks compact row geometry, aligned titles, passive status clicks,
workspace accessibility, unknown/named workspaces, narrow long-title wrapping and
the shared spacing/size/disabled-omission sequence, including enabled restoration.
`tests/qml/tst_application_actions.qml` covers direct Close acknowledgement,
snapshot-owned removal, busy guards, failure/retry and removed-command focus
restoration, plus acknowledged versus pending focus, window-scoped success,
localized messages, failure/cancellation, superseding requests and independence
from compositor focus through actual commands/replies.
Shared control and chooser tests cover the reused focus/menu foundations.

The HTML is an offline design study, not a replacement for native tests or a
catalog of installed applications. Hardware compositor, screen-reader and
localized-font acceptance remain separate live checks.
