pragma ComponentBehavior: Bound

import QtQuick
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

        delegate: WorkspaceButton {
            required property int modelData
            controller: root.controller
            screenName: root.screenName
            workspaceId: modelData
        }
    }
}
