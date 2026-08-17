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
    // Keep the focused monitor's layer surface mapped so a media-key press does
    // not pay a Wayland surface creation/configure round trip before appearing.
    visible: targetIsFocused
    implicitWidth: 376
    implicitHeight: 104
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
        left: Math.max(0, Math.round(((window.screen ? window.screen.width : 376)
            - window.implicitWidth) / 2))
    }

    Rectangle {
        id: surface

        anchors.left: parent.left
        anchors.right: parent.right
        height: parent.height
        radius: Ui.Theme.panelRadius + 4
        color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.97)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.38)
        opacity: window.controller.osdVisible ? 1 : 0
        y: window.controller.osdVisible ? 0 : 8

        Ui.Elevation {
            anchors.fill: parent
            radius: surface.radius
            level: 3
            z: -1
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Ui.Theme.withAlpha(Ui.Theme.accent, Ui.Theme.dark ? 0.055 : 0.035)
        }

        Rectangle {
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - parent.radius * 2
            height: 2
            radius: 1
            color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.72)
        }

        Behavior on opacity {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                // Feedback should appear immediately; only its dismissal fades.
                duration: window.controller.osdVisible ? 0 : Ui.Theme.animationFast
                easing.type: Ui.Theme.easingStandard
            }
        }
        Behavior on y {
            enabled: !Ui.Theme.noAnimations
            NumberAnimation {
                duration: Ui.Theme.animationFast
                easing.type: Easing.OutCubic
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

            Rectangle {
                id: iconBadge

                width: 52
                height: 52
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: Ui.Theme.mix(Ui.Theme.selected, Ui.Theme.accent, 0.12)
                border.width: 1
                border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.48)

                Ui.Elevation {
                    anchors.fill: parent
                    radius: iconBadge.radius
                    level: 1
                    z: -1
                }

                Text {
                    anchors.centerIn: parent
                    text: window.controller.osdIcon
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: 27
                }
            }

            Column {
                width: parent.width - iconBadge.width - valueBadge.width - parent.spacing * 2
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
                    id: track

                    width: parent.width
                    height: 10
                    visible: window.controller.osdProgressVisible
                    radius: height / 2
                    color: Ui.Theme.input
                    border.width: 1
                    border.color: Ui.Theme.withAlpha(Ui.Theme.controlBorder, 0.72)

                    Rectangle {
                        id: progressFill

                        width: parent.width * window.controller.osdPercent / 100
                        height: parent.height
                        radius: parent.radius
                        color: Ui.Theme.accent

                        Behavior on width {
                            enabled: !Ui.Theme.noAnimations
                            NumberAnimation {
                                duration: Ui.Theme.animationFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        x: Math.max(0, Math.min(track.width - width,
                            progressFill.width - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: width / 2
                        color: Ui.Theme.accentText
                        border.width: 4
                        border.color: Ui.Theme.accent
                        visible: track.visible

                        Behavior on x {
                            enabled: !Ui.Theme.noAnimations
                            NumberAnimation {
                                duration: Ui.Theme.animationFast
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: valueBadge

                width: Math.max(58, valueLabel.implicitWidth + Ui.Theme.spacingMd * 2)
                height: 38
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.16)
                border.width: 1
                border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.40)

                Text {
                    id: valueLabel

                    anchors.centerIn: parent
                    text: window.controller.osdValueLabel
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                    onTextChanged: if (!Ui.Theme.noAnimations) valuePulse.restart()
                }

                SequentialAnimation {
                    id: valuePulse

                    NumberAnimation {
                        target: valueBadge
                        property: "scale"
                        to: 0.88
                        duration: Math.round(Ui.Theme.animationFast * 0.35)
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: valueBadge
                        property: "scale"
                        to: 1
                        duration: Math.round(Ui.Theme.animationFast * 0.65)
                        easing.type: Easing.OutBack
                    }
                }
            }
        }
    }
}
