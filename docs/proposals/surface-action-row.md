# Standard surface action row (historical implementation)

**Visual layout superseded:** the delivered
[circular panel action contract](circular-panel-actions.md) replaces the labelled
primary and single row described below. Primaries now align with the title/icon;
secondaries sit below/right, and all command buttons are icon-only circles.
Keyboard routing, menu safety and accessible names from this implementation remain.
The following audit and test counts are historical, not current acceptance.

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

## Delivery and validation

All six steps are implemented. Layout exceptions have been removed; content/footer
control sizing remains independent of the surface row. The shared row reserves the
same height when a primary disappears, avoiding Activity content jumps. Navigation
tracks actual delegate additions/removals rather than assuming Repeater.count means
all buttons exist. Badges, activation and accessible descriptions resolve the same
live key mapping without restoring stale bindings onto surviving buttons.

Overflow uses a styled, modal Popup with menu accessibility roles, arrow/Tab
navigation, Enter/Space activation, disabled-item skipping and prior-focus
restoration. Qt's standard Menu dismissed itself on Alt and exposed the underlying
header chord; regression tests now cover that failure. Header commands are blocked
while overflow is open, and overflow closes on resizing, model changes or blocked
navigation/deactivation.

Validation commands (from `nix develop --no-write-lock-file`):

- `tests/run-qmllint.sh`: passed, zero lint warnings.
- `tests/run-qml-tests.sh`: **333 passes including lifecycle hooks, 0 failures,
  0 skipped**. Includes seven new surface-action cases, migrated keyboard hints,
  Activity custom-header activation and Media/Tray integration.
- `node tests/check-provider-model.js qml/Shelllist/Core/Model.js`: 12 checks passed.
- `tests/run-runtime-smoke.sh`: both native offscreen configurations loaded.
- `git diff --check`: passed.

Logs: `/tmp/surface-actions-final-qml.log` and
`/tmp/surface-actions-final-checks.log`. The full run emitted an intermittent Qt
engine-teardown diagnostic about seven items still being created; the earlier
layout-only run also emitted this diagnostic (six items). No behavioral cases
failed. Offscreen smoke reports the platform's unsupported window-mask warning.
The full sibling-aware Nix gate was not run for this change.

Manual acceptance still required: inspect real compositor placement at normal and
HiDPI scales, hardware AltGr/WM shortcut interaction, screen-reader announcements
and contrast in the deployed theme. No live session was restarted or deployed.

## Acceptance

- Right-aligned, vertically centred single row at compact/wide widths and scale.
- Primary labelled and larger; secondary neutral except semantic danger/warning.
- Overflow does not overlap, wrap or leave invisible active header shortcuts.
- Visible keys unique and stable across disabled states/reordering.
- Numeric header shortcuts removed; AltGr, modal and focused-editor safety retained.
- Menu Escape/focus restoration, no repeated shortcut effects, accessible names.
- Live compositor, hardware AltGr and screen-reader checks are manual acceptance;
  automated offscreen tests cannot establish these.
