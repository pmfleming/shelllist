# Material roadmap implementation

## Item 2 — search bar

Chooser search uses a 56px Surface Container High pill, a 16px native editor,
primary caret/leading-icon focus feedback, a live filtered-result count and
embedded surface actions. Form inputs keep their outlined frames. Native query
selection, printable-key continuation, IME ownership and guarded Alt+Enter are
unchanged. Progress, errors and domain status remain in the footer rather than
being discarded in favor of a count; empty footers collapse.

Validation: strict lint for changed shared components and the native Qt suite,
including search selection, guarded pointer/accessibility actions, empty counts,
constrained header bounds and stable dimensions across work-area sizes.

## Item 3 — segmented result rows

Shared rows are 64px high with 2px gaps, filled surfaces, grouped outer corners
and 40px leading containers (including fallback icons). Avatars spring between
rounded squares and selected circles; focus remains immediate and tonal. The
selected row alone shows its detail chevron and, when available/enabled, the
actual primary-action icon with an Enter cue. Names retain a fixed content edge
when selection changes. Domain signal/weather data and independent running-app,
delete and bulk-selection actions remain intact. Native list navigation,
selection and explicit detail opening are unchanged.

Validation: strict lint and 302 Qt passes, including avatar/selection states,
disabled action cues, unselected trailing-area pointer selection, keyboard
navigation and domain workflows. The previously documented Displays engine
teardown advisory appeared again; there were no failed or skipped cases.

## Item 5 — tonal containment

Detail cards now use opaque Surface Container Low without borders or shadows.
Disclosures are full-width, minimum-56px list items with trailing expand icons;
children/drafts stay alive and attention still forces content open. Shared toggle
rows have a 56px minimum with larger labels/supporting text. A passive SettingRow
places labels/supporting text beside native controls, with a faint within-card
separator; Sleep policies adopts it without changing acknowledgement or safety
behavior. Form inputs retain their outlines. Spacing tokens are 4/8/12/16/24/32.

Validation: strict lint and 303 Qt passes, including light/dark opaque card tones,
wrapped setting bounds, draft retention, attention disclosure and existing power
policy/navigation tests.
