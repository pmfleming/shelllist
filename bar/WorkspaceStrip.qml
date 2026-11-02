pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root
    required property BarController controller
    required property string screenName
    required property int layoutDensity
    readonly property var items: controller.workspaces.lifecycle?.monitors?.[screenName] || []
    readonly property var workspaceIds: items.map(item => item.id)
    readonly property int activeWorkspaceIndex: items.findIndex(item => item.active)
    readonly property bool urgent: items.some(item => item.urgent)
    implicitWidth: workspaceRow.implicitWidth + addButton.width
    implicitHeight: 37
    function revealActive(): void {
        const delegate = workspaceRepeater.itemAt(activeWorkspaceIndex);
        if (!delegate) return;
        if (delegate.x < viewport.contentX)
            viewport.contentX = delegate.x;
        else if (delegate.x + delegate.width > viewport.contentX + viewport.width)
            viewport.contentX = Math.max(0, delegate.x + delegate.width - viewport.width);
    }
    onItemsChanged: Qt.callLater(revealActive)
    onWidthChanged: Qt.callLater(revealActive)
    Flickable {
        id: viewport
        objectName: "workspaceViewport"
        anchors.left: parent.left
        anchors.right: addButton.left
        height: parent.height
        contentWidth: workspaceRow.implicitWidth
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        onContentWidthChanged: Qt.callLater(root.revealActive)
        Row {
            id: workspaceRow
            height: viewport.height
            spacing: root.layoutDensity >= 2 ? 2 : 4
            Repeater {
                id: workspaceRepeater
                model: root.items
                delegate: Item {
                    id: workspaceDelegate
                    required property var modelData
                    width: workspaceButton.implicitWidth + (modelData.divider_before ? 9 : 0)
                    height: viewport.height
                    Rectangle {
                        visible: workspaceDelegate.modelData.divider_before
                        width: 1
                        height: parent.height / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: Ui.Theme.controlBorder
                    }
                    WorkspaceButton {
                        id: workspaceButton
                        anchors.right: parent.right
                        controller: root.controller
                        screenName: root.screenName
                        workspaceId: workspaceDelegate.modelData.id
                        presentation: workspaceDelegate.modelData
                        width: implicitWidth
                        height: viewport.height
                    }
                }
            }
        }
    }
    Ui.ActionControl {
        id: addButton
        objectName: "workspaceAdd"
        anchors.right: parent.right
        width: 34
        height: parent.height
        activeFocusOnTab: false
        browseIndicatorVisible: false
        interactive: root.controller.backend.ready && !!root.controller.workspaces.lifecycle?.available
        accessibleName: qsTr("Create workspace on %1. Super+Ctrl+N").arg(root.screenName)
        onClicked: root.controller.createWorkspace(root.screenName)
        Ui.GlyphLabel { anchors.centerIn: parent; glyph: "add" }
        Ui.StateLayer { focusTarget: addButton; onClicked: addButton.activate() }
    }
    Rectangle {
        objectName: "workspaceUrgencyAggregate"
        anchors.right: addButton.left
        anchors.top: parent.top
        width: 5
        height: 5
        radius: 3
        color: Ui.Theme.danger
        visible: root.urgent
    }
}
