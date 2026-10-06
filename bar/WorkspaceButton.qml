import Quickshell
import Quickshell.Widgets
import QtQuick
import Shelllist.Ui as Ui
import "BarWorkspacePresentation.js" as Presentation

Ui.ActionControl {
    id: button

    required property BarController controller
    required property string screenName
    required property int workspaceId
    property bool compact: false
    readonly property var workspace: Presentation.workspaceFor(controller.workspaces, workspaceId)
    readonly property bool active: Presentation.activeWorkspaceId(controller.workspaces, screenName) === workspaceId
    readonly property bool occupied: !!workspace && Number(workspace.windows || 0) > 0
    readonly property var activeWindow: active ? Presentation.activeWindowFor(controller.workspaces, screenName) : null
    readonly property string iconName: activeWindow ? Presentation.windowIconName(activeWindow) : Presentation.workspaceIconName(workspaceId)

    readonly property bool iconAvailable: iconName.length > 0 && Quickshell.hasThemeIcon(iconName)
    activeFocusOnTab: false
    browseIndicatorVisible: false
    focusSurface: workspaceDisc
    accessibleName: qsTr("Workspace %1").arg(workspaceId) + (workspace ? ". " + (workspace.last_window_title || "") + (workspace.urgent ? qsTr(". Urgent") : "") : "")
    onClicked: controller.focusWorkspace(workspaceId)

    width: compact ? 23 : 27
    height: 51

    Rectangle {
        id: workspaceDisc
        objectName: "workspaceDisc"
        anchors.centerIn: parent
        width: button.compact ? 23 : 27
        height: width
        radius: height / 2
        color: button.active ? Ui.Theme.selected : (button.occupied ? Ui.Theme.surfaceRaised : "transparent")
        opacity: button.active ? 1 : (button.occupied ? 0.82 : 0.48)
        border.width: button.workspace && button.workspace.urgent ? 2 : (button.active ? 1 : 0)
        border.color: button.workspace && button.workspace.urgent ? Ui.Theme.danger : Ui.Theme.strongBorder

        Ui.InteractiveBehavior on color {
            duration: Ui.Theme.animationFast
            easingType: Easing.Linear
        }
        Ui.InteractiveBehavior on opacity {
            duration: Ui.Theme.animationFast
            easingType: Easing.Linear
        }

        IconImage {
            id: appIcon
            anchors.centerIn: parent
            implicitSize: button.compact ? 17 : 20
            visible: button.iconAvailable && status === Image.Ready
            source: button.iconAvailable ? Quickshell.iconPath(button.iconName) : ""
            scale: button.active ? 1.08 : 0.94

            Ui.InteractiveBehavior on scale {
                duration: Ui.Theme.animationNormal
                easingType: Easing.OutBack
            }
        }

        Text {
            anchors.centerIn: parent
            visible: !button.iconAvailable || appIcon.status !== Image.Ready
            text: Presentation.workspaceGlyph(button.workspaceId) || String(button.workspaceId)
            color: button.active ? Ui.Theme.selectedText : Ui.Theme.text
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightBold

            Ui.InteractiveBehavior on color {
                duration: Ui.Theme.animationFast
                easingType: Easing.Linear
            }
        }
    }

    Ui.StateLayer {
        focusTarget: button
        radius: height / 2
        stateColor: Ui.Theme.accent
        showStateBackground: true
        hoverOpacity: 0.10
        pressedOpacity: 0.16
        onClicked: button.activate()
    }
}
