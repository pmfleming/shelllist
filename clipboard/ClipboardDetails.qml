pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property ClipboardController controller
    required property real uiScale
    readonly property var selected: controller.selectedResult || ({})
    readonly property var entry: controller.details ? controller.details.entry : ({})
    readonly property var files: controller.details ? controller.details.files : []
    readonly property var imageFacts: controller.details ? controller.details.image : null
    readonly property int headerHeight: Math.max(58, Math.round(66 * uiScale))
    readonly property int toolbarHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))

    color: "transparent"
    clip: true

    Column {
        anchors.fill: parent
        anchors.leftMargin: Math.round(Ui.Theme.spacingLg * pane.uiScale)
        anchors.rightMargin: Math.round(Ui.Theme.spacingLg * pane.uiScale)
        spacing: Math.round(Ui.Theme.spacingMd * pane.uiScale)

        RowLayout {
            width: parent.width
            height: pane.headerHeight
            spacing: Ui.Theme.spacingMd

            Ui.IconTile {
                Layout.preferredWidth: 58
                Layout.preferredHeight: 54
                icon: pane.selected.icon || "󰅇"
                iconColor: pane.entry.current ? Ui.Theme.active : Ui.Theme.accent
                iconSize: Math.round(Ui.Theme.iconSizeLarge * pane.uiScale)
                backgroundColor: Ui.Theme.selected
                borderColor: Ui.Theme.strongBorder
            }

            Column {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Ui.Theme.spacingXs
                Text {
                    width: parent.width
                    text: pane.selected.title || "Clipboard entry"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Math.round(Ui.Theme.fontSizeTitle * pane.uiScale)
                    font.weight: Ui.Theme.fontWeightBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: pane.selected.subtitle || ""
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Math.max(Ui.Theme.fontSizeCaption, Math.round(Ui.Theme.fontSizeSmall * pane.uiScale))
                    elide: Text.ElideRight
                }
            }
        }

        Ui.ActionToolbar {
            width: parent.width
            height: pane.toolbarHeight
            actions: [{
                id: "close-details", label: "Back", icon: "󰁍", shortcut: "Left",
                visible: true, enabled: true,
                presentation: { group: "toolbar", tone: "normal", width: 104 }
            }]
            group: "toolbar"
            alignRight: false
            controlHeight: pane.toolbarHeight
            onTriggered: pane.controller.closeDetails()
        }

        Item {
            width: parent.width
            height: Math.max(0, parent.height - pane.headerHeight - pane.toolbarHeight - 2 * parent.spacing)

            Ui.CenteredMessage {
                anchors.fill: parent
                visible: pane.controller.detailsLoading
                text: "Loading entry details…"
                font.pixelSize: Ui.Theme.fontSizeTitle
            }
            Ui.CenteredMessage {
                anchors.fill: parent
                visible: !pane.controller.detailsLoading && pane.controller.detailsError.length > 0
                text: pane.controller.detailsError
                font.pixelSize: Ui.Theme.fontSizeBody
            }

            Ui.DetailFlickable {
                anchors.fill: parent
                visible: !pane.controller.detailsLoading && pane.controller.detailsError.length === 0 && !!pane.controller.details

                Ui.DetailCard {
                    title: "Preview"
                    height: pane.controller.thumbnail || (pane.controller.details && pane.controller.details.text) ? 250 : 112

                    Image {
                        visible: !!pane.controller.thumbnail
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        source: pane.controller.thumbnail ? "file://" + pane.controller.thumbnail.path : ""
                    }
                    TextEdit {
                        visible: !pane.controller.thumbnail && pane.controller.details && pane.controller.details.text !== null
                        anchors.fill: parent
                        text: pane.controller.details ? (pane.controller.details.text || "") : ""
                        color: Ui.Theme.text
                        selectionColor: Ui.Theme.selected
                        selectedTextColor: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeBody
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.Wrap
                    }
                    Ui.CenteredMessage {
                        anchors.fill: parent
                        visible: !pane.controller.thumbnail && (!pane.controller.details || pane.controller.details.text === null)
                        text: "Binary preview is unavailable"
                        font.pixelSize: Ui.Theme.fontSizeBody
                    }
                }

                Ui.DetailCard {
                    title: "Metadata"
                    height: 154
                    RowLayout {
                        anchors.fill: parent
                        spacing: Ui.Theme.spacingLg
                        Ui.DetailField { Layout.fillWidth: true; label: "Type"; value: pane.entry.kind || "—" }
                        Ui.DetailField { Layout.fillWidth: true; label: "MIME"; value: pane.entry.mime || "—" }
                        Ui.DetailField { Layout.fillWidth: true; label: "Size"; value: pane.entry.byte_size !== undefined ? pane.entry.byte_size + " bytes" : "—" }
                        Ui.DetailField {
                            Layout.fillWidth: true
                            label: "Dimensions"
                            value: pane.imageFacts ? pane.imageFacts.width + " × " + pane.imageFacts.height : "—"
                        }
                    }
                }

                Ui.DetailCard {
                    visible: pane.files.length > 0
                    title: "Files"
                    height: Math.min(300, 76 + pane.files.length * 42)
                    Column {
                        anchors.fill: parent
                        spacing: Ui.Theme.spacingSm
                        Repeater {
                            model: pane.files
                            delegate: RowLayout {
                                required property var modelData
                                width: parent.width
                                height: 34
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.display_name
                                    color: modelData.exists ? Ui.Theme.text : Ui.Theme.danger
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeBody
                                    elide: Text.ElideMiddle
                                }
                                Text {
                                    text: modelData.operation === "cut" ? "Move" : "Copy"
                                    color: Ui.Theme.mutedText
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeCaption
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
