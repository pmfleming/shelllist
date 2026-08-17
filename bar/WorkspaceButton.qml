import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: button

    required property BarController controller
    required property string screenName
    required property int workspaceId
    property bool compact: false
    readonly property var workspace: Presentation.workspaceFor(controller.workspaces, workspaceId)
    readonly property bool active: Presentation.activeWorkspaceId(controller.workspaces,
        screenName) === workspaceId
    readonly property string asset: Presentation.workspaceAsset(workspaceId)

    width: compact ? 23 : 27
    height: 51

    Rectangle {
        anchors.centerIn: parent
        width: button.compact ? 23 : 27
        height: width
        radius: Ui.Theme.baseRadius
        color: button.workspaceId === 1 ? Ui.Theme.window : Ui.Theme.input
        opacity: button.active ? 1 : 0.45
        border.width: button.workspace && button.workspace.urgent ? 2 : 0
        border.color: Ui.Theme.danger

        Image {
            anchors.centerIn: parent
            width: button.compact ? 17 : 20
            height: width
            visible: button.asset.length > 0
            source: visible ? Qt.resolvedUrl(button.asset) : ""
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Text {
            anchors.centerIn: parent
            visible: button.asset.length === 0
            text: Presentation.workspaceGlyph(button.workspaceId)
            color: "#ffffff"
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightBold
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: button.controller.focusWorkspace(button.workspaceId)
    }
}
