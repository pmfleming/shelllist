pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "BarWorkspacePresentation.js" as Presentation

Item {
    id: root
    required property BarController controller
    required property string screenName
    required property int layoutDensity
    readonly property var workspaceIds: Presentation.workspaceIds(controller.workspaces, screenName)
    readonly property int activeWorkspaceIndex: Presentation.activeWorkspaceIndex(controller.workspaces, screenName)
    readonly property int workspaceButtonWidth: 32
    readonly property bool urgent: workspaceIds.some(id => !!Presentation.workspaceFor(controller.workspaces, id)?.urgent)
    implicitWidth: workspaceRow.implicitWidth
    implicitHeight: 37
    function revealActive(): void {
        const x = Math.max(0, activeWorkspaceIndex) * (workspaceButtonWidth + workspaceRow.spacing);
        if (x < viewport.contentX)
            viewport.contentX = x;
        else if (x + workspaceButtonWidth > viewport.contentX + viewport.width)
            viewport.contentX = Math.max(0, x + workspaceButtonWidth - viewport.width);
    }
    onActiveWorkspaceIndexChanged: Qt.callLater(revealActive)
    onWidthChanged: Qt.callLater(revealActive)
    Flickable {
        id: viewport
        objectName: "workspaceViewport"
        anchors.fill: parent
        contentWidth: workspaceRow.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        Row {
            id: workspaceRow
            height: viewport.height
            spacing: root.layoutDensity >= 2 ? 2 : 4
            Repeater {
                model: root.workspaceIds
                delegate: WorkspaceButton {
                    required property int modelData
                    controller: root.controller
                    screenName: root.screenName
                    workspaceId: modelData
                    width: root.workspaceButtonWidth
                    height: viewport.height
                }
            }
        }
    }
    // Aggregate urgency stays visible even if its workspace is scrolled out.
    Rectangle {
        objectName: "workspaceUrgencyAggregate"
        anchors.right: parent.right
        anchors.top: parent.top
        width: 5
        height: 5
        radius: 3
        color: Ui.Theme.danger
        visible: root.urgent
    }
}
