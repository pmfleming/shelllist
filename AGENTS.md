# Shelllist contributor contract

Before changing or adding a panel, read `docs/chooser-keyboard-workflow.md`.
It is the mandatory interaction model for every panel and supersedes older
keyboard behavior in proposals/reviews. Use the approved visual roles and review
checklist in `docs/panel-ui-standardization.md`; reusable controls belong in
`qml/Shelllist/Ui/`, not new panel-local setting wrappers. Review added numeric
font/spacing/radius overrides with `python3 tests/review-panel-ui.py --base <ref>`;
chart/calendar/map geometry may be intentional, but needs a reason and owner.
Keep error/blocked/pending state visible and passive labels readable. New labels,
headings, Help and telemetry must not become extra editable stops.

Use shared `ProviderChooserSurface`/`PanelSurface` navigation and shared editable
controls. Tab/Shift+Tab traverse only editable fields; arrows browse results or
edit natively, never traverse fields. Enter saves, Escape discards, and Tab saves
while continuing editing. Action buttons use Alt+letter commands, not field Tab
stops. Field-local drafts must not trigger backend writes before save, except
explicit continuous-preview sliders with rollback. Highlight only the editable
control, with distinct browsing/editing states.

Keep domain acknowledgement, validation, retry and safety guards intact. Add or
update actual Qt interaction tests when changing this behavior and update the
contract documentation. Do not introduce panel-local variants of the key model.
