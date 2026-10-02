# Standard surface action row

## Contract

One right-aligned row below the identity/title/status, primary first, followed by
stable secondary actions. A primary is labelled, larger and accent-filled;
secondary actions are compact and neutral. Danger/warning semantics survive.
No primary is invented for an information/settings-only surface. In-content
settings, notification replies, list filters and modal actions are not headers.

At narrow widths secondary icons remain compact, then trailing actions move to a
More menu; the primary and More remain visible, never wrapping. Menu actions keep
normal keyboard navigation and do not expose header badges. More uses Alt+M.

Hold Alt for the existing 250 ms to reveal letter badges; Alt+letter activates
immediately. Release/focus loss/deactivation/popups/modals clear hints. Plain
letters still type. Disabled buttons keep their key but cannot execute. One
explicit accessKey per action, independent of array position/localized label.
Alt+S remains screenshot; Alt+M is reserved for overflow. Duplicate/invalid keys
must fail closed (no ambiguous dispatch), not be reassigned dynamically.

## Audit and explicit key map

| Surface | Primary | Secondary keys | Current variation / migration |
| --- | --- | --- | --- |
| Applications | Activate A (Launch/Focus) | New tile N, Close C | Inline header opt-in; remove exception |
| Wi-Fi | Connect C / Disconnect D / Cancel X | Forget F, Sign in I, Share H | Split primary/toolbar rows |
| Bluetooth | Pair P / Connect C / Disconnect D | Reset R, Forget F | Split rows, destructive disconnect |
| Clipboard | Paste P / Copy C for binary | Copy C, Paste as file F, Edit E | Raw descriptors; binary hides secondary copy |
| Displays | Preview P | Identify I, Enable/Disable E | Narrow stacked header; remove exception |
| Audio | none | Mixer A | Volume increments stay with volume setting |
| Media | Play/Pause P | Previous B, Next N, Rewind R, Forward F | Move playback toolbar to header; exclude Inspect |
| Tray | Activate A | Menu O, Secondary activation C, Scroll up U/down D | Merge split application toolbars; exclude Inspect |
| Activity | Today T (overview only) | Overview O (details), Refresh R | Custom header, outside navigation discovery |
| Time & Weather | none | none | Shared identity header, no commands |
| Battery & Power | none | none | Information header; settings stay in content |
| Notifications | none | none | Message/reply actions and list-level dismissal remain contextual |

Inspect remains the system chooser's result primary action (Enter opens details).
Promoting playback/activation visually in its inspector does not change that route.
Existing Enter, F5, Ctrl+T, Ctrl+Tab and domain command shortcuts remain intact.

## Implementation sequence

1. Audit and approve this contract/key map (this document).
2. Introduce SurfaceActionRow; replace DetailsHeader's layout variants, keep
   unrelated ActionToolbar consumers unchanged; provide overflow menu.
3. Add theme-driven primary/secondary button sizing, label measurement and
   emphasis, with usable minimum hit sizes and constrained labels.
4. Normalize accessKey metadata and share the displayed button mapping between
   activation, badges and accessibility; discover custom surface rows too.
5. Assign keys and migrate Applications/Displays overrides, system chooser and
   Activity; preserve action dispatch/confirmation and existing display edits.
6. Extend layout/keyboard/provider regressions; run lint, native QML suite,
   provider JS checks and runtime smoke; update keyboard documentation.

Each step is committed separately. Existing uncommitted display work is excluded.

## Acceptance

- Right-aligned, vertically centred single row at compact/wide widths and scale.
- Primary labelled and larger; secondary neutral except semantic danger/warning.
- Overflow does not overlap, wrap or leave invisible active header shortcuts.
- Visible keys unique and stable across disabled states/reordering.
- Numeric header shortcuts removed; AltGr, modal and focused-editor safety retained.
- Menu Escape/focus restoration, no repeated shortcut effects, accessible names.
- Live compositor, hardware AltGr and screen-reader checks are manual acceptance;
  automated offscreen tests cannot establish these.
