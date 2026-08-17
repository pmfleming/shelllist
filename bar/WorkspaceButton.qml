import Quickshell
import Quickshell.Widgets
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
    readonly property bool occupied: !!workspace && Number(workspace.windows || 0) > 0
    readonly property string iconName: Presentation.workspaceIconName(workspaceId)

    width: compact ? 23 : 27
    height: 51

    Rectangle {
        anchors.centerIn: parent
        width: button.compact ? 23 : 27
        height: width
        radius: Ui.Theme.baseRadius
        color: button.active ? "transparent"
            : (button.workspaceId === 1
                ? Ui.Theme.withAlpha(Ui.Theme.window, 0.58)
                : Ui.Theme.withAlpha(Ui.Theme.input, button.occupied ? 0.72 : 0.42))
        opacity: button.active ? 1 : (button.occupied ? 0.82 : 0.48)
        border.width: button.workspace && button.workspace.urgent ? 2 : 0
        border.color: Ui.Theme.danger

        Behavior on color {
            enabled: !Ui.Theme.noAnimations
            ColorAnimation { duration: Ui.Theme.animationFast }
        }
        Behavior on opacity {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation { duration: Ui.Theme.animationFast }
        }

        IconImage {
            anchors.centerIn: parent
            implicitSize: button.compact ? 17 : 20
            visible: button.iconName.length > 0
            source: Quickshell.iconPath(button.iconName, "application-x-executable")
            scale: button.active ? 1.08 : 0.94

            Behavior on scale {
                enabled: !Ui.Theme.noAnimations
                NumberAnimation {
                    duration: Ui.Theme.animationNormal
                    easing.type: Easing.OutBack
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: button.iconName.length === 0
            text: Presentation.workspaceGlyph(button.workspaceId)
            color: button.active ? Ui.Theme.accent : Ui.Theme.text
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightBold

            Behavior on color {
                enabled: !Ui.Theme.noAnimations
                ColorAnimation { duration: Ui.Theme.animationFast }
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
        onClicked: button.controller.focusWorkspace(button.workspaceId)
    }

}
