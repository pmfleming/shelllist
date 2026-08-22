import Quickshell
import Quickshell.Widgets
import QtQuick
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property string screenName
    required property int layoutDensity
    property int maximumWidth: layoutDensity === 0 ? 260 : 160
    readonly property var activeWindow: Presentation.activeWindowFor(
        controller.workspaces, screenName)
    readonly property string sourceTitle: activeWindow
        ? (activeWindow.title || activeWindow.class_name || "Desktop") : ""

    visible: activeWindow !== null && layoutDensity <= 1
    implicitWidth: visible ? Math.min(maximumWidth,
        iconFrame.width + titleLabel.implicitWidth + stateGlyph.implicitWidth + 34) : 0
    implicitHeight: 37

    Rectangle {
        anchors.fill: parent
        radius: 0
        color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.56)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.controlBorder, 0.72)
    }

    Rectangle {
        id: iconFrame

        anchors.left: parent.left
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        width: 27
        height: 27
        radius: 0
        color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.14)

        IconImage {
            anchors.centerIn: parent
            width: 18
            height: 18
            source: Quickshell.iconPath(Presentation.windowIconName(root.activeWindow),
                "application-x-executable")
        }
    }

    Ui.PulsingLabel {
        id: titleLabel

        anchors.left: iconFrame.right
        anchors.leftMargin: 8
        anchors.right: stateGlyph.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.sourceTitle
        color: Ui.Theme.text
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
        font.weight: Ui.Theme.fontWeightMedium
    }

    Text {
        id: stateGlyph

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.activeWindow && root.activeWindow.fullscreen ? "󰊓"
            : (root.activeWindow && root.activeWindow.floating ? "󰉈" : "")
        color: Ui.Theme.accent
        font.family: Ui.Theme.iconFontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }

    Ui.StateLayer {
        focusTarget: root
        radius: 0
        stateColor: Ui.Theme.text
        showStateBackground: true
        onClicked: root.controller.openSurface("applications")
    }


    Behavior on implicitWidth {
        enabled: !Ui.Theme.noAnimations
        NumberAnimation {
            duration: Ui.Theme.animationNormal
            easing.type: Ui.Theme.easingStandard
        }
    }
}
