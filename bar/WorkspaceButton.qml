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

    // Bar maintainer: extras include stable origin and ID, so reveal uses bounds.
    implicitWidth: presentation?.temporary ? Math.min(160, extraLabel.implicitWidth + 44) : 32
    implicitHeight: 34

    Rectangle {
        id: workspaceTile
        objectName: "workspaceTile"
        anchors.centerIn: parent
        width: button.width
        height: 34
        radius: 9
        // Selection is chromatic, with a size cue independent of hue. Occupancy
        // uses glyph weight; neither state changes category identity or hit geometry.
        color: "transparent"
        border.width: button.urgent ? 1 : 0
        border.color: Ui.Theme.danger
        Item {
            id: categoryIcon
            visible: !button.presentation?.temporary
            anchors.centerIn: parent
            width: button.active ? 22 : 20
            height: width
            readonly property bool terminal: button.presentation.icon === "terminal"
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
                visible: !categoryIcon.terminal
                glyph: button.presentation.icon
                color: categoryIcon.foreground
                font.pixelSize: categoryIcon.width
                // Other categories and the numeric fallback retain glyph weight.
                font.weight: button.occupied ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
                Accessible.ignored: true
            }
        }
        Row {
            id: extraRow
            anchors.centerIn: parent
            spacing: 4
            visible: !!button.presentation.temporary
            Item {
                width: 20
                height: 20
                Image {
                    id: originIcon
                    anchors.fill: parent
                    source: button.presentation.icon && button.presentation.icon !== "workspace" ? Quickshell.iconPath(button.presentation.icon, "application-x-executable") : ""
                    sourceSize: Qt.size(width, height)
                    visible: status === Image.Ready
                }
                Ui.GlyphLabel {
                    anchors.centerIn: parent
                    visible: !originIcon.visible
                    glyph: "workspaces"
                    color: button.active ? Ui.Theme.accent : Ui.Theme.mutedText
                }
            }
        Text {
            id: extraLabel
            objectName: "workspaceOrigin"
            width: Math.min(implicitWidth, workspaceTile.width - 36)
            height: 20
            verticalAlignment: Text.AlignVCenter
            visible: !!button.presentation?.temporary
            text: button.presentation ? button.presentation.number + " · " + button.presentation.label : ""
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            font.weight: button.occupied ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
            color: button.active ? Ui.Theme.accent : button.occupied ? Ui.Theme.text : Ui.Theme.mutedText
            elide: Text.ElideRight
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
