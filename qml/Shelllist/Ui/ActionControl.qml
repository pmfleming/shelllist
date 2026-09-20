import QtQuick

// Presentation-free activation shared by buttons, tabs, toggles and bar actions.
Rectangle {
    property string accessibleName: ""
    property bool interactive: true
    signal clicked

    color: "transparent"
    // Busy controls may keep focus, but must not activate until ready again.
    activeFocusOnTab: enabled && (interactive || activeFocus)
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: activate()

    function activate(): void {
        if (enabled && interactive)
            clicked();
    }

    Keys.onPressed: function (event) {
        if (![Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key))
            return;
        if (!event.isAutoRepeat)
            activate();
        event.accepted = true;
    }
}
