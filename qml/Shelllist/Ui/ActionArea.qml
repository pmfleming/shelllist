import QtQuick

Item {
    id: area

    required property string accessibleName
    property real focusRadius: Theme.controlRadius
    readonly property bool hovered: pointer.containsMouse
    signal clicked

    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName
    Accessible.onPressAction: activate()
    Keys.onReturnPressed: activate()
    Keys.onEnterPressed: activate()
    Keys.onSpacePressed: activate()

    function activate(): void {
        if (enabled)
            clicked();
    }

    Rectangle {
        anchors.fill: parent
        radius: area.focusRadius
        color: "transparent"
        border.width: area.activeFocus ? 1 : 0
        border.color: Theme.accent
    }

    ControlPointerArea {
        id: pointer
        focusTarget: area
        onClicked: area.activate()
    }
}
