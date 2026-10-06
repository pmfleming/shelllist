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
- Unrecognized browser sessions keep their browser identity/icon and content title.
  No guesses from episode names, artwork URLs or substrings. No page-origin field
  exists in the current UI contract; general browser-tab recognition requires
  upstream trusted metadata. Recognizing Spotify does **not** classify it as music.
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

- `tst_media_presentation.qml`: exact identity/fallback/classification, deduplicated
  metadata, override policy, timing bounds, paused/future/stale/invalid snapshots.
- `tst_system_choosers.qml`: actual rendered icons (theme and bundled fallbacks),
  contained artwork, theme contrast, numeric values, selected-session isolation,
  native key delivery for field drafts/save/discard, More modality, capability and
  acknowledgement guards, inactive/hidden cleanup and no implicit playback writes.
- `tst_surface_actions.qml`: explicit overflow at wide/narrow widths, overflow-only
  geometry, native More navigation, disabled entries, chord isolation and restore.
