# Shelllist contributor contract

Before changing or adding a panel, read `docs/chooser-keyboard-workflow.md`.
It is the mandatory interaction model for every panel and supersedes older
keyboard behavior in proposals/reviews.

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
