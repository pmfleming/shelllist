# Material roadmap implementation

## Item 2 — search bar

Chooser search uses a 56px Surface Container High pill, a 16px native editor,
primary caret/leading-icon focus feedback and embedded surface actions. Form inputs keep their outlined frames. Native query
selection, printable-key continuation, IME ownership and guarded Alt+Enter are
unchanged. Counts, progress, errors and domain status remain in the status footer,
not in the search bar; empty footers collapse.

Validation: strict lint for changed shared components and the native Qt suite,
including search selection, guarded pointer/accessibility actions,
constrained header bounds and stable dimensions across work-area sizes.

## Item 3 — segmented result rows

Shared rows are 64px high with 2px gaps, filled surfaces, grouped outer corners
and 40px leading containers (including fallback icons). Avatars spring between
rounded squares and selected circles; focus remains immediate and tonal. The
selected row alone shows its detail chevron, with no primary-action or Enter
indicator. Row actions such as clipboard delete sit beside the chevron. Names retain a fixed content edge
when selection changes. Domain signal/weather data and independent running-app,
delete and bulk-selection actions remain intact. Native list navigation,
selection and explicit detail opening are unchanged.

Validation: strict lint and 302 Qt passes, including avatar/selection states,
unselected trailing-area pointer selection, keyboard
navigation and domain workflows. The previously documented Displays engine
teardown advisory appeared again; there were no failed or skipped cases.

## Item 5 — tonal containment

Detail cards now use opaque Surface Container Low without borders or shadows.
Additional sections show their contents immediately below passive headings,
without expand/collapse controls. Read-only information is excluded from keyboard
browsing and focus restoration; editable controls remain addressable. Shared toggle
rows have a 56px minimum with larger labels/supporting text. A passive SettingRow
places labels/supporting text beside native controls, with a faint within-card
separator; Sleep policies adopts it without changing acknowledgement or safety
behavior. Form inputs retain their outlines. Spacing tokens are 4/8/12/16/24/32.

Validation: strict lint and 303 Qt passes, including light/dark opaque card tones,
wrapped setting bounds, draft retention and existing power
policy/navigation tests.

## Item 8 — explicit modifier-held shortcut hints

Hold Alt for 250ms to reveal numbered header keycaps; hold Ctrl for a tab-bar
Ctrl+Tab cue, updated to Ctrl+Shift+Tab while Shift is held. Numbers come from the
same ordered button list that dispatches Alt+1…9, including disabled slots.
Keycaps are decorative and never steal focus or activate a control. Modifier
observation preserves native editing and any existing key-forwarding targets.
Release, focus/window loss, native menus, blocked navigation and deactivation
clear hints; Ctrl+Alt/AltGr chords are excluded. Single-panel tab bars are covered
as well as split inspectors. No hover/focus/open-triggered labels or F1 help.

Validation: 307 Qt passes, strict QML lint, native runtime smoke and the full
sibling-aware co-development gate pass. Tests cover short/long holds, inline and
two-row action numbering, disabled slots, native text input, existing forwarding,
menus/modals, timer cancellation, focus loss and Battery's bottom tab bar.
Logs: `/tmp/material-item8-focused.txt`, `/tmp/material-roadmap-smoke.txt` and
`/tmp/material-roadmap-full-gate.txt`. The offscreen window-mask advisory and the
intermittent, previously documented Displays teardown advisory remain separate
from live compositor/IME/screen-reader acceptance. No service was deployed.
