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
