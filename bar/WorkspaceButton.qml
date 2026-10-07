import QtQuick
import Shelllist.Ui as Ui
import "BarWorkspacePresentation.js" as Presentation

Ui.ActionControl {
    id: button

    required property BarController controller
    required property string screenName
    required property int workspaceId
    readonly property var workspace: Presentation.workspaceFor(controller.workspaces, workspaceId)
    readonly property var category: Presentation.workspaceCategory(workspaceId)
    readonly property bool active: Presentation.activeWorkspaceId(controller.workspaces, screenName) === workspaceId
    readonly property bool occupied: !!workspace && Number(workspace.windows || 0) > 0
    readonly property bool urgent: !!workspace && !!workspace.urgent

    objectName: "barWorkspace:" + workspaceId
    activeFocusOnTab: false
    browseIndicatorVisible: false
    focusSurface: workspaceTile
    accessibleName: qsTr("Workspace %1").arg(workspaceId)
        + (category ? ". " + category.label : "")
        + (occupied ? qsTr(". Occupied") : "")
        + (urgent ? qsTr(". Urgent") : "")
        + (workspace && workspace.last_window_title ? ". " + workspace.last_window_title : "")
    Accessible.checked: active
    onClicked: controller.focusWorkspace(workspaceId)

    implicitWidth: 32
    implicitHeight: 34

    Rectangle {
        id: workspaceTile
        objectName: "workspaceTile"
        anchors.centerIn: parent
        width: 32
        height: 34
        radius: 9
        // Selection is immediate. Category identity and hit geometry never
        // change with the focused app, and occupancy is not a disabled state.
        color: button.active ? Ui.Theme.selected : "transparent"
        border.width: button.urgent ? 1 : 0
        border.color: Ui.Theme.danger
        Ui.GlyphLabel {
            objectName: "workspaceCategoryGlyph"
            anchors.centerIn: parent
            glyph: button.category ? button.category.icon : String(button.workspaceId)
            color: button.active ? Ui.Theme.selectedText : Ui.Theme.text
            font.pixelSize: 18
            Accessible.ignored: true
        }
        Rectangle {
            objectName: "workspaceOccupancy"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 1
            width: button.active ? 8 : 3
            height: button.active ? 2 : 3
            radius: height / 2
            visible: button.active || button.occupied
            color: button.active ? Ui.Theme.selectedText : Ui.Theme.mutedText
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
