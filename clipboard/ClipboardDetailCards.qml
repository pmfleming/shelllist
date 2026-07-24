pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: cards

    required property ClipboardController controller
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : ({})
    readonly property var files: detailState.value ? detailState.value.files : []
    readonly property var imageFacts: detailState.value ? detailState.value.image : null

    Ui.DetailCard {
        title: "Preview"
        height: cards.detailState.thumbnail || (cards.detailState.value && cards.detailState.value.text) ? 250 : 112

        Image {
            visible: !!cards.detailState.thumbnail
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize.width: width
            sourceSize.height: height
            source: cards.detailState.thumbnail ? "file://" + cards.detailState.thumbnail.path : ""
        }
        TextEdit {
            visible: !cards.detailState.thumbnail && cards.detailState.value && cards.detailState.value.text !== null
            anchors.fill: parent
            text: cards.detailState.editing ? cards.detailState.editDraft
                : (cards.detailState.value ? (cards.detailState.value.text || "") : "")
            color: Ui.Theme.text
            selectionColor: Ui.Theme.selected
            selectedTextColor: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            readOnly: !cards.detailState.editing
            selectByMouse: true
            onTextChanged: if (cards.detailState.editing && activeFocus) cards.detailState.editDraft = text
            wrapMode: TextEdit.Wrap
        }
        Ui.CenteredMessage {
            anchors.fill: parent
            visible: !cards.detailState.thumbnail
                && (!cards.detailState.value || cards.detailState.value.text === null)
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
            Ui.DetailField { Layout.fillWidth: true; label: "Type"; value: cards.entry.kind || "—" }
            Ui.DetailField { Layout.fillWidth: true; label: "MIME"; value: cards.entry.mime || "—" }
            Ui.DetailField {
                Layout.fillWidth: true
                label: "Size"
                value: cards.entry.byte_size !== undefined ? cards.entry.byte_size + " bytes" : "—"
            }
            Ui.DetailField {
                Layout.fillWidth: true
                label: "Dimensions"
                value: cards.imageFacts ? cards.imageFacts.width + " × " + cards.imageFacts.height : "—"
            }
        }
    }

    Ui.DetailCard {
        visible: cards.files.length > 0
        title: "Files"
        height: Math.min(300, 76 + cards.files.length * 42)
        Column {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: cards.files
                delegate: RowLayout {
                    id: fileRow

                    required property var modelData
                    width: parent.width
                    height: 34
                    Text {
                        Layout.fillWidth: true
                        text: fileRow.modelData.display_name
                        color: fileRow.modelData.exists ? Ui.Theme.text : Ui.Theme.danger
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeBody
                        elide: Text.ElideMiddle
                    }
                    Text {
                        text: fileRow.modelData.operation === "cut" ? "Move" : "Copy"
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
        }
    }
}
