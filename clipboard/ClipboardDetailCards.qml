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
    readonly property bool directTextEdit: entry.kind === "text"
    readonly property int availableCardHeight: Math.max(0, height - cardSpacing)
    readonly property int previewCardHeight: Math.max(220, Math.round(availableCardHeight * 0.66))
    readonly property int dataCardHeight: Math.max(250, availableCardHeight - previewCardHeight)

    Ui.DetailCard {
        title: cards.entry.kind
            ? cards.entry.kind.charAt(0).toUpperCase() + cards.entry.kind.slice(1)
            : "Clipboard item"
        height: cards.previewCardHeight

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
            readOnly: !cards.detailState.editing || cards.detailState.saveInFlight
            selectByMouse: true
            onActiveFocusChanged: if (cards.directTextEdit) cards.detailState.setEditorFocused(activeFocus)
            onTextChanged: if (cards.detailState.editing && activeFocus) {
                if (cards.directTextEdit)
                    cards.detailState.updateEditDraft(text);
                else
                    cards.detailState.editDraft = text;
            }
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

    Ui.DetailColumnCard {
        title: "Data"
        height: cards.dataCardHeight

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 96

            Ui.DetailGrid {
                anchors.fill: parent
                entries: [{
                    label: "Type",
                    value: cards.entry.kind || "—"
                }, {
                    label: "MIME",
                    value: cards.entry.mime || "—"
                }, {
                    label: "Size",
                    value: Ui.Format.bytes(cards.entry.byte_size)
                }, {
                    label: "Dimensions",
                    value: cards.imageFacts
                        ? cards.imageFacts.width + " × " + cards.imageFacts.height
                        : "—"
                }]
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Ui.Theme.border
        }

        Text {
            Layout.fillWidth: true
            text: "Files"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                anchors.fill: parent
                visible: cards.files.length === 0
                text: "No associated files"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                verticalAlignment: Text.AlignVCenter
            }

            Ui.ScrollableListView {
                id: fileList

                anchors.fill: parent
                visible: cards.files.length > 0
                model: cards.files
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: RowLayout {
                    id: fileRow

                    required property var modelData
                    width: fileList.width
                    height: 34
                    spacing: Ui.Theme.spacingMd

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
