# Bar media shortcuts

The resident shell registers these compositor commands exactly once, independently
of monitor count and panel visibility, using shared `ShelllistGlobalShortcut`:

| Command | Suggested Hyprland key | Action |
| --- | --- | --- |
| `shelllist:media-play-pause` | `XF86AudioPlay` | Play/pause |
| `shelllist:media-back` | `XF86AudioPrev` | Previous track or rewind 30 seconds |
| `shelllist:media-forward` | `XF86AudioNext` | Next track or forward 30 seconds |

`MediaShortcuts` and the bar's pointer/accessibility buttons call the same
`BarController.performMediaTransport` entry point. It uses the existing
`BarMediaPresentation` capability and track/seek policy, including the acknowledged
per-player mode and automatic content classification. No second player-selection
algorithm or direct playerctl/MPRIS path is introduced.

Each activation captures the currently active/pinned native player ID. Missing
players, unavailable media, disconnected backend and unsupported actions do not
dispatch or queue effects. Play/pause checks the appropriate play/pause capability
for the observed playback state; back/forward require their respective track or
seek capabilities plus control permission. Unknown command names fail closed.

Commands never open Media, move focus, alter an editor draft, pin a player or
optimistically change playback state. Responses keep existing backend validation,
acknowledgement/error handling and no automatic effect retry. The Media panel's
selected-player Alt commands and field-navigation/editing model are unchanged.
No new field stops, geometry, hints or panel-local key handlers are added.

The compositor owns actual key assignments. README contains opt-in Hyprland
bindings; this change neither installs/reloads live bindings nor deploys/restarts
Shelllist. Dedicated media keys can be replaced with user-selected chords. Do not
register a second media handler for the same chord. Suggested bindings do not
opt into lock-screen delivery or key repeat.

## Tests

`tests/qml/tst_media_chip.qml` uses real Qt, the production shortcut adapter and
controller, and a substituted compositor registration/recording daemon transport.
Emitting the registered shortcut's `pressed` signal covers:

- identical keyboard-dispatch and pointer payloads in track, seek and automatic
  spoken-content modes, including captured player IDs and ±30-second offsets;
- current-player replacement without re-registering shortcuts;
- play/pause, previous/next, seek and control capability rejection;
- missing/unavailable/disconnected state, no effect retry after native failure;
- editor focus/text retention, no panel opening and no optimistic playback change.

These are actual Qt signal/routing tests, not physical-key or live-compositor
acceptance. Live Hyprland binding delivery, installed package rollout and real
player effects are deliberately not exercised by the private tests.
