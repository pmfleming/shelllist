pragma ComponentBehavior: Bound

import QtQuick
import "BarPresentation.js" as Presentation

Row {
    id: root

    required property BarController controller
    required property string screenName
    required property int layoutDensity
    spacing: layoutDensity === 0 ? 8 : layoutDensity === 1 ? 5 : 2
    leftPadding: layoutDensity < 2 ? 10 : 4
    rightPadding: leftPadding

    Repeater {
        model: Presentation.workspaceIds(root.controller.workspaces, root.screenName)

        delegate: WorkspaceButton {
            required property int modelData
            controller: root.controller
            screenName: root.screenName
            workspaceId: modelData
            compact: root.layoutDensity >= 2
        }
    }
}
