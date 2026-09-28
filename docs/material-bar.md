# Material bar and desktop chooser slice

Implementation of the accepted group/media direction; the detailed overflow,
clock and artwork gesture choices below are an explicit prototype for review,
not newly attributed interview requirements. Nothing is deployed by this work.

## Presentation

One rounded, 94%-opaque surface occupies the existing 51px exclusive zone.
Groups, in order: **Workspaces, Media, Network, Bluetooth, Battery,
Notifications, Tray, Clock/date**. Group backgrounds are transparent. Focused
application, Audio, Displays, Power profile, Activity, Updates and separate
Timezone pods are gone; their destinations remain accessible independently.
There are no hover tooltips or persistent battery/notification numbers.
Accessible metadata retains detailed values.

- Workspaces retain their established icon assignments and show the focused
  application's actual icon when available. Missing theme icons fall back to
  workspace glyphs/numbers, not broken-image placeholders. Occupancy and active
  state remain distinct. Urgent workspaces have a static outline and an aggregate
  indicator even when horizontally clipped; they never grab keyboard focus.
- Workspace allocation is capped at 27% of bar width and scrolls independently,
  revealing the active workspace. Tray shows at most three inline items on wide
  outputs, one at the next tier, and its list button otherwise. Media collapses
  to its list/artwork button below 700px. Below the full group's minimum width,
  the continuous strip scrolls horizontally with an explicit forward/back
  overflow button. No group or font is silently shrunk away.
- Notification urgency is a static danger color, including under DND. The bell
  opens Notifications; right click opens Activity; middle click toggles DND.
  Tray needs-attention state gets a static outline. No urgency animation or
  automatic activation is introduced.
- Clock/date use local 24-hour numerical `yyyy-MM-dd HH:mm`, compacting to
  `MM-dd HH:mm`; full date and timezone remain nonvisual metadata.
- Lua Hyprland blur/no-animation rules are namespace-scoped, reapplied after
  compositor config reload, and ignore alpha below 0.01. Transparent outer bar
  margins are excluded from its input region. Offscreen captures do **not**
  validate either compositor blur or native input masks.

## Media policy and actions

`bar-daemon` owns selection and per-player mode preferences. It tracks observed
transitions into playing, independently of the player-list order. In automatic
mode it chooses the most recently started currently playing player, then the most
recent retained player when none are playing. Initial discovery cannot recover
historical start times: its fallback is deterministic. An explicit **Pin this
player** action wins until Automatic is requested or the player exits. Merely
browsing or restoring an inspected player does not pin it.

Mode overrides are **daemon-session-local, per MPRIS player ID**, surviving
frontend recreation but removed when that player exits. They are not disk
preferences. Explicit music/video/podcast content metadata and Spotify track or
episode URLs support conservative classification; audio MIME types and player
identity alone do not establish music. Media details can override Automatic with
Tracks or Seek. Unknown, video and podcast content seek **−30/+30 seconds**;
music uses Previous/Next. Icons and accessible names distinguish the operations.
Every control respects its actual capability; no unsupported seek is replaced
with a misleading track action. Old daemons without preference fields leave the
new preference controls disabled.

The bar is artwork (or its music fallback) plus three transport icons, without
track/artist/player text, a cycle button or a progress strip/timer. Artwork opens
Media as this prototype's explicit detail route. Pin/mode changes wait for daemon
state; neither those changes nor presentation restoration invokes playback.

## Routes and menu safety

Audio/Media/Tray retain independent CLI, global shortcut and Home Manager routes.
Audio contains current default devices, mute controls, volume commands and the
full mixer; device routing still belongs to that mixer, not a fabricated daemon
API. Displays, Battery power profiles, Applications, Activity and Time & Weather
retain their chooser routes. Workspace switching retains compositor shortcuts.
Update journals have `shelllist:update-logs`, with configurable Super+Shift+U in
Home Manager; no status pod is required to reach them.

Tray provides explicit activation, secondary activation, scrolling and native
menus. Duplicate IDs disable effects instead of choosing an arbitrary instance.
Native menus hold the chooser's focus-loss guard before opening, block competing
chooser navigation, and restore an ordinary focus target only in the same live
invocation. Missing/slow menus time out, deactivation cancels them, and late open
signals cannot restore an old invocation. Menu handles and open state are never
serialized into presentation memory.

## Validation and remaining acceptance

Native Qt tests cover group order at 1200/700/300px, pictorial versus nonvisual
values, urgent color, overflow access, transport modes/capabilities, explicit
player targeting, acknowledged settings, no restoration replay, and native-menu
lifecycle through a recording platform boundary. Rust tests cover conservative
classification, recency/order independence, pin/automatic/exit behavior and
mode lifetime; backend and frontend contract fixtures are regenerated and validated.
The final sibling-aware gates pass: **280 Qt passes / 198 behavioral cases** in
Shelllist, **141 Rust unit tests plus two integration tests** in bar-daemon.
Strict QML lint, TypeScript generation checks, runtime/gallery smoke and all
sibling/contract gates pass. Logs: `/tmp/material-item5-shelllist-final-gate.log`
and `/tmp/material-item5-bar-gate.log`.

Reviewed light/dark offscreen bar captures at 1200/700/300px and production-font
control galleries. This caught missing workspace theme icons and led to the
explicit glyph fallback. The gallery verifies packaged Roboto Flex, Noto Sans
and Material Symbols Rounded. Evidence lives under `/tmp/material-bar-*.png`,
`/tmp/material-production-*.png` and `/tmp/material-production-captures.log`.

Still separate: owner review of prototype decisions, live layer-shell/menu
focus/input masks, blur/GPU performance, final spring feel, larger-text/hardware
IME and screen-reader acceptance. Legacy compositor blur and automatic reduced
motion outside Hyprland are not claimed. The independently reproduced baseline
Displays teardown warning also remains unresolved; it reappeared in a direct
Qt-suite run, without failed cases or a new suppression.
