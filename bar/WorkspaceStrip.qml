pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Row {
    id: root

    required property BarController controller
    required property string screenName
    spacing: 8
    leftPadding: 10
    rightPadding: 10

    Repeater {
        model: Presentation.workspaceIds(root.controller.workspaces, root.screenName)

        delegate: Item {
            id: workspaceButton
            required property int modelData
            readonly property int workspaceId: modelData
            readonly property var workspace: Presentation.workspaceFor(root.controller.workspaces, workspaceId)
            readonly property bool active: Presentation.activeWorkspaceId(root.controller.workspaces,
                root.screenName) === workspaceId
            readonly property bool urgent: !!(workspace && workspace.urgent)
            readonly property string asset: Presentation.workspaceAsset(workspaceId)

            width: 27
            height: 51

            Rectangle {
                anchors.centerIn: parent
                width: 27
                height: 27
                radius: Ui.Theme.baseRadius
                color: workspaceButton.workspaceId === 1 ? Ui.Theme.window : Ui.Theme.input
                opacity: workspaceButton.active ? 1 : 0.45
                border.width: workspaceButton.urgent ? 2 : 0
                border.color: Ui.Theme.danger

                Image {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    visible: workspaceButton.asset.length > 0
                    source: workspaceButton.asset.length > 0
                        ? Qt.resolvedUrl(workspaceButton.asset) : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: workspaceButton.asset.length === 0
                    text: Presentation.workspaceGlyph(workspaceButton.workspaceId)
                    color: "#ffffff"
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightBold
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.controller.focusWorkspace(workspaceButton.workspaceId)
            }
        }
    }
}
