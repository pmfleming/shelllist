pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Controls.Popup {
    id: details

    required property BatteryController controller
    objectName: "sleepDetailsPopup"
    parent: Controls.Overlay.overlay
    anchors.centerIn: parent
    width: Math.max(0, Math.min(440, (parent ? parent.width : 440) - 2 * Ui.Theme.spacingMd))
    height: Math.max(0, Math.min(body.contentHeight + 2 * padding, (parent ? parent.height : 600) - 2 * Ui.Theme.spacingMd))
    padding: Ui.Theme.spacingMd
    modal: true
    dim: false
    focus: true
    closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
    onVisibleChanged: controller.sleepDetailsOpen = visible

    Connections {
        target: details.controller
        function onViewTabChanged(): void {
            if (details.controller.viewTab !== "power")
                details.close();
        }
        function onUiActiveChanged(): void {
            if (!details.controller.uiActive)
                details.close();
        }
    }

    background: Rectangle {
        color: Ui.Theme.surfaceRaised
        radius: Ui.Theme.cardRadius
        border.color: Ui.Theme.strongBorder
        border.width: 1
    }

    contentItem: Flickable {
        id: body
        objectName: "sleepDetailsScroll"
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar {}

        Column {
            id: column
            width: body.width
            spacing: Ui.Theme.spacingMd

            RowLayout {
                width: parent.width

                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: qsTr("Sleep details")
                    font.pixelSize: Ui.Theme.fontSizeHeading
                    font.weight: Ui.Theme.fontWeightBold
                }
                Ui.FlatIconButton {
                    objectName: "sleepDetailsClose"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    icon: "󰅖"
                    accessibleName: qsTr("Close sleep details")
                    toolTip: accessibleName
                    onClicked: details.close()
                }
            }

            Ui.FieldLabel {
                width: parent.width
                text: qsTr("Locks before sleeping. Routine handlers briefly prepare the system; they do not block sleep.")
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }

            Ui.FieldLabel {
                objectName: "sleepFailureDetails"
                width: parent.width
                visible: text.length > 0
                text: details.controller.sleepError || details.controller.powerSleep.error || ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Ui.Theme.danger
            }

            Repeater {
                model: details.visible ? ["suspend", "hibernate"] : []

                delegate: Column {
                    id: capability
                    required property string modelData
                    width: column.width
                    spacing: Ui.Theme.spacingXs

                    Ui.ThemeText {
                        width: parent.width
                        text: Presentation.sleepActionName(capability.modelData)
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.FieldLabel {
                        objectName: "sleepCapability-" + capability.modelData
                        width: parent.width
                        text: Presentation.sleepCapabilityDescription(details.controller.powerSleep, capability.modelData)
                        wrapMode: Text.Wrap
                        elide: Text.ElideNone
                    }
                }
            }

            Ui.FieldLabel {
                width: parent.width
                visible: details.controller.powerSleep.available && details.controller.sleepBlockers.length === 0
                text: qsTr("No sleep blockers")
            }

            Repeater {
                model: details.visible ? [
                    { heading: qsTr("Blocking sleep"), items: details.controller.sleepBlockers, blocking: true },
                    { heading: qsTr("Preparing for sleep"), items: details.controller.sleepDelayHandlers, blocking: false }
                ] : []

                delegate: Column {
                    id: group
                    required property var modelData
                    width: column.width
                    visible: modelData.items.length > 0
                    spacing: Ui.Theme.spacingSm

                    Ui.ThemeText {
                        width: parent.width
                        text: group.modelData.heading
                        color: group.modelData.blocking ? Ui.Theme.warning : Ui.Theme.text
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }

                    Repeater {
                        model: group.modelData.items

                        delegate: Column {
                            id: handler
                            required property var modelData
                            width: group.width
                            spacing: Ui.Theme.spacingXs

                            Ui.ThemeText {
                                objectName: "sleepHandlerName"
                                width: parent.width
                                text: Presentation.sleepHandlerName(handler.modelData.who)
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                            }
                            Ui.FieldLabel {
                                objectName: "sleepHandlerReason"
                                width: parent.width
                                text: handler.modelData.why || qsTr("No reason provided")
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                elide: Text.ElideNone
                                font.pixelSize: Ui.Theme.fontSizeSmall
                            }
                        }
                    }
                }
            }
        }
    }
}
