# Media presentation

Implemented from the approved [icon-first M3 proposal](proposals/media-pixel-m3.html).
The panel retains `ProviderChooserSurface`, the shared circular header, shared
editable controls and daemon acknowledgement/capability guards.

## Presentation

- Show/book/artist context replaces a generic browser heading. Episode/track title
  remains in the card; duplicate artist/album/title metadata is suppressed.
- Spotify, Pocket Casts and Audible resolve from exact known desktop IDs or explicit
  MPRIS identities (including daemon-provided isolated-browser labels). Installed
  theme assets take precedence over bundled official application icons. Spotify's
  installed `spotify-client` icon is an alias, not the MPRIS service ID.
- Daemon-provided `source.service` labels recognize YouTube, Vimeo, SoundCloud,
  Spotify, Pocket Casts and Audible independently of the controlling player.
  Details show labels such as **SoundCloud · via Zen**; service names are searchable.
  Installed service icons are preferred, with existing bundled service assets or
  the player's installed icon as fallback. Logos are never used as cover art.
- Unrecognized browser sessions keep their browser identity/icon and content title.
  No guesses from episode names, artwork URLs or substrings. Shelllist does not
  parse or fetch `source.url`; source recognition belongs to bar-daemon and is a
  player-supplied presentation hint, not authenticated website identity.
  Recognizing a service does **not** classify its content. With source metadata,
  only the daemon's recognized content kind selects the content glyph/context;
  older source-less isolated-app labels retain their existing fallbacks.
- Resolve presentation only: retain original player IDs for selection, pinning,
  transport and acknowledgement. Search includes service and album identity.
- Covers use `PreserveAspectFit` inside square containers, never cropped wallpaper.
  Text uses paired M3 secondary-container colors. The shared desktop HCT palette
  is the safe fallback; artwork-derived seed extraction is not implemented.
- Pause/equalizer/stop icons replace status prose. Timing uses elapsed and negative
  remaining numbers; reported playback rate is a passive `1×`-style value. No help
  paragraphs, playback captions or permanent shortcut legend inside the panel.
  Accessible names retain status, content kind and timing scope. Errors remain text.
- Progress is read-only and never seeks. Unknown/invalid duration or position uses
  `—:—` with no track. Valid position is clamped to duration. Playing snapshots may
  extrapolate at the reported rate for at most five seconds after observation;
  paused snapshots never advance. Timers stop when hidden, inactive or disconnected.
  A static expressive wave is shown only while playing with motion enabled; the
  reduced-motion/paused presentation is straight. It is not an audio waveform.
- Music uses previous/next; spoken/unknown content uses ±30s seek, respecting saved
  per-player overrides and all capability guards. The other pair is in shared More.
  Read-only rate is not a speed menu; there are no invented chapters, device routes
  or whole-book totals. Audiobook timing refers to the reported MPRIS segment.
- Pin to bar remains immediate and acknowledged. Bar controls remains a deferred
  shared dropdown (Enter saves, Escape discards, Tab saves and continues). When a
  different player is pinned, an icon-only Alt+A command restores automatic choice.

## Browser source metadata: first pass

bar-daemon preserves a validated HTTP(S) content URL (or supported native Spotify
URI), a nullable service key, and classification provenance (`mpris`, `url`, or
`unknown`). Explicit content metadata wins. Clear YouTube/Vimeo video paths and
Spotify track/episode paths provide offline content hints; SoundCloud, Audible
and Pocket Casts site recognition alone does not establish music/book/episode
content. Unknown websites retain their original title/artist/album and browser
identity. Missing or unfamiliar source fields remain compatible with older daemons.

No network enrichment is implemented: no oEmbed/API requests, scraped pages,
cookies or synthesized thumbnails. Zen currently supplies the screenshot's
YouTube title/channel, URL, duration and position, but no artwork and an empty
album; its paused rate is zero. This pass improves service/video recognition, not
those absent fields. Supplied artwork always remains the cover source.

Source URLs can contain sensitive query/fragment values. They are transient
metadata, not search text, clickable links or instructions to fetch/open anything.
Changing/clearing a URL updates presentation without pinning, playback or saving
an editing draft. Existing editable field traversal, save/discard transactions
and capability guards are unchanged. Actual Qt source-refresh tests exercise
those invariants against a non-active inspected player.

## Super+M investigation (2026-10-06)

The live Hyprland configuration file contained:

```lua
hl.bind("SUPER + M", hl.dsp.global("shelllist:media"))
```

However, `hyprctl -j binds` contained **no M binding**, while
`hyprctl -j globalshortcuts` did list `shelllist:media`. The saved Home Manager
configuration had changed without the running compositor applying that binding.
This was not a missing Shelllist shortcut registration or a media capability guard.

`hyprctl reload` applied the saved configuration with no config errors. The live
binding then appeared with modmask 64 (Super), key M, non-repeating. Invoking
`hl.dsp.global("shelllist:media")` through `hyprctl dispatch` was checked against
`shelllist status`: Media opened and the next invocation closed it. Physical
keyboard delivery remains a manual acceptance check.

If it recurs, compare the **live** binds with the saved configuration, check
`hyprctl configerrors`, and reload after a desktop configuration deployment.
Do not add a second exec binding on top of an existing global toggle: two handlers
can open and immediately close the panel. No shortcut-handler code change was
needed for the observed issue. The generic Shelllist Home Manager module still
has configurable Super+Shift+M; this desktop's Lua config deliberately uses Super+M.

## Tests

- `tst_media_presentation.qml`: exact identity/source/fallback/classification,
  browser-origin labels, deduplicated metadata, override policy, timing bounds,
  paused/future/stale/invalid snapshots.
- `tst_media_sources.qml`: service/browser icon fallback without invented covers,
  source changes/clearing during an editable draft, unchanged field traversal,
  service search, original-player command routing and disabled capability guards.
- `tst_system_choosers.qml`: actual rendered icons (theme and bundled fallbacks),
  contained artwork, theme contrast, numeric values, selected-session isolation,
  native key delivery for field drafts/save/discard, More modality, capability and
  acknowledgement guards, inactive/hidden cleanup and no implicit playback writes.
- `tst_surface_actions.qml`: explicit overflow at wide/narrow widths, overflow-only
  geometry, native More navigation, disabled entries, chord isolation and restore.
