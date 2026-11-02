import QtQuick
import Quickshell
import Shelllist.Ui as Ui

Ui.ActionControl {
    id: button

    required property BarController controller
    required property string screenName
    required property int workspaceId
    required property var presentation
    readonly property bool active: presentation.active
    readonly property bool occupied: presentation.occupied
    readonly property bool urgent: presentation.urgent

    objectName: "barWorkspace:" + workspaceId
    activeFocusOnTab: false
    browseIndicatorVisible: false
    focusSurface: workspaceTile
    accessibleName: presentation.accessible_name
    Accessible.checked: active
    onClicked: controller.focusWorkspace(workspaceId)

    // Names and IDs remain accessible; every workspace uses the same icon target.
    implicitWidth: 32
    implicitHeight: 34

    Rectangle {
        id: workspaceTile
        objectName: "workspaceTile"
        anchors.centerIn: parent
        width: button.width
        height: 34
        radius: 9
        clip: true
        // Selection is chromatic, with a size cue independent of hue. Occupancy
        // uses glyph weight; neither state changes category identity or hit geometry.
        color: "transparent"
        border.width: button.urgent ? 1 : 0
        border.color: Ui.Theme.danger
        Item {
            id: categoryIcon
            anchors.centerIn: parent
            width: button.active ? 22 : 20
            height: width
            readonly property bool terminal: !button.presentation.temporary && button.presentation.icon === "terminal"
            readonly property color foreground: button.active ? Ui.Theme.accent : button.occupied ? Ui.Theme.text : Ui.Theme.mutedText

            Ui.TerminalGlyph {
                objectName: "workspaceTerminalGlyph"
                anchors.fill: parent
                visible: categoryIcon.terminal
                color: categoryIcon.foreground
                bold: button.occupied
            }
            Ui.GlyphLabel {
                objectName: "workspaceCategoryGlyph"
                anchors.centerIn: parent
                visible: !categoryIcon.terminal && !originIcon.visible
                glyph: !button.presentation.temporary && Ui.MaterialIcons.name(button.presentation.icon)
                    ? button.presentation.icon : "workspaces"
                color: categoryIcon.foreground
                font.pixelSize: categoryIcon.width
                // Category and fallback icons retain occupancy weight.
                font.weight: button.occupied ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                Accessible.ignored: true
            }
            Image {
                id: originIcon
                objectName: "workspaceOriginIcon"
                anchors.fill: parent
                source: button.presentation.temporary && button.presentation.icon && button.presentation.icon !== "workspace"
                    ? Quickshell.iconPath(button.presentation.icon, "application-x-executable") : ""
                sourceSize: Qt.size(width, height)
                visible: button.presentation.temporary && status === Image.Ready
                Accessible.ignored: true
            }
        }
        Rectangle {
            objectName: "workspaceUrgency"
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 2
            width: 4
            height: 4
            radius: 2
            color: Ui.Theme.danger
            visible: button.urgent
        }
    }
    Ui.StateLayer {
        anchors.fill: workspaceTile
        focusTarget: button
        radius: workspaceTile.radius
        stateColor: Ui.Theme.accent
        showStateBackground: true
        hoverOpacity: 0.10
        pressedOpacity: 0.16
        onClicked: button.activate()
    }
}
