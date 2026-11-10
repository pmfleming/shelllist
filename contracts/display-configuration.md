# Display configuration interaction

Global settings remain behind the Displays cog; output-specific settings live in
the selected display's expansion card. Focus preferences remain global.

Placement and identity fields use shared FormField/DropDownList/TextField controls.
Changing monitor matching, reference, side, alignment or gap only changes the local
draft. Escape discards a field; Enter/Tab saves it into that draft. Preview submits
all displays to the daemon; Keep/Revert retain the existing durable transaction.
The backend resolves identity, placement and validation authoritatively. Frontend
relative geometry exists only for the canvas preview.

Identity defaults to monitor identity; explicit connector matching handles
indistinguishable monitors. Identify remains the existing named action and passive
manufacturer/model/serial values remain in Information, outside field traversal.

Coverage: `tests/qml/tst_displays.qml` exercises relative resizing, native gap
save/discard, matching selection and one whole-layout preview without early writes.

Profiles are a subpage behind the global cog: capture the current layout, rename,
select a profile for Preview, edit priority and AC/lid conditions, choose fallback,
and enable automatic switching. Each display expansion card marks its membership
as required/optional for matching the active profile. These metadata edits are
acknowledged by the daemon; pending operations disable conflicting controls.
Closing a pending profile preview reverts only its own returned trial identity.

DisplayPlacementSettings and DisplayProfilesPane compose domain fields with the
shared Ui controls; they introduce no alternative setting/editor wrapper or key
model. The Displays maintainer owns these compositions. No numeric style override
was added (panel-review advisory reviewed).
