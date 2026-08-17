import Quickshell
import Quickshell.Wayland
import QtQuick
import Shelllist.Ui as Ui

PanelWindow { // qmllint disable uncreatable-type
    id: window

    required property var targetScreen
    required property BarController controller
    readonly property string focusedScreenName: controller.workspaces
        ? (controller.workspaces.focused_monitor || "") : ""
    readonly property bool targetIsFocused: focusedScreenName.length > 0
        ? (!!screen && screen.name === focusedScreenName)
        : (Quickshell.screens.length > 0 && screen === Quickshell.screens[0])

    screen: targetScreen
    visible: controller.osdVisible && targetIsFocused
    implicitWidth: 340
    implicitHeight: 92
    color: "transparent"
    mask: Region {}
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shelllist-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        bottom: true
        left: true
    }
    margins { // qmllint disable unresolved-type unqualified
        bottom: 86
        left: Math.max(0, Math.round(((window.screen ? window.screen.width : 340)
            - window.implicitWidth) / 2))
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surfaceRaised
        border.width: 1
        border.color: Ui.Theme.controlBorder
        opacity: window.visible ? 1 : 0

        Behavior on opacity {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                duration: Ui.Theme.animationFast
                easing.type: Ui.Theme.easingStandard
            }
        }

        Row {
            anchors {
                fill: parent
                leftMargin: Ui.Theme.spacingLg
                rightMargin: Ui.Theme.spacingLg
                topMargin: Ui.Theme.spacingMd
                bottomMargin: Ui.Theme.spacingMd
            }
            spacing: Ui.Theme.spacingMd

            Text {
                width: 38
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignHCenter
                text: window.controller.osdIcon
                color: Ui.Theme.accent
                font.family: Ui.Theme.iconFontFamily
                font.pixelSize: 28
            }

            Column {
                width: parent.width - 38 - valueLabel.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Ui.Theme.spacingSm

                Text {
                    width: parent.width
                    text: window.controller.osdLabel
                    color: Ui.Theme.text
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }

                Rectangle {
                    width: parent.width
                    height: 7
                    visible: window.controller.osdProgressVisible
                    radius: height / 2
                    color: Ui.Theme.input

                    Rectangle {
                        width: parent.width * window.controller.osdPercent / 100
                        height: parent.height
                        radius: parent.radius
                        color: Ui.Theme.accent

                        Behavior on width {
                            enabled: !Ui.Theme.noAnimations
                            NumberAnimation {
                                duration: Ui.Theme.animationFast
                                easing.type: Ui.Theme.easingStandard
                            }
                        }
                    }
                }
            }

            Text {
                id: valueLabel

                anchors.verticalCenter: parent.verticalCenter
                text: window.controller.osdValueLabel
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }
    }
}
