pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: cards
    objectName: "clipboardDetailPage"

    required property ClipboardController controller
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : ({})
    readonly property var files: detailState.value ? detailState.value.files : []
    readonly property var imageFacts: detailState.value ? detailState.value.image : null
    readonly property bool directTextEdit: entry.kind === "text"
    readonly property string selectedTab: controller.detailsTab
    onSelectedTabChanged: contentY = 0

    Ui.DetailColumnCard {
        visible: cards.selectedTab === "data" && cards.detailState.editError.length > 0
        height: visible ? implicitHeight : 0
        title: qsTr("Unsaved clipboard draft")
        Ui.ThemeText {
            Layout.fillWidth: true
            text: cards.detailState.editError
            wrapMode: Text.WordWrap
            color: Ui.Theme.danger
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.ActionButton {
                objectName: "retryClipboardEdit"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: qsTr("Retry save")
                enabled: !cards.controller.actionInFlight && !cards.detailState.editBeginPending
                onClicked: cards.detailState.retryEdit()
            }
            Ui.ActionButton {
                objectName: "discardClipboardEdit"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: qsTr("Discard draft")
                enabled: !cards.controller.actionInFlight && !cards.detailState.editBeginPending
                onClicked: cards.detailState.discardFailedEdit()
            }
        }
    }

    Ui.DetailCard {
        objectName: "clipboardDataCard"
        visible: cards.selectedTab === "data"
        title: cards.entry.kind ? cards.entry.kind.charAt(0).toUpperCase() + cards.entry.kind.slice(1) : "Clipboard item"
        height: Math.max(220, cards.height)

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
            objectName: "clipboardTextEditor"
            visible: !cards.detailState.thumbnail && cards.detailState.value && cards.detailState.value.text !== null
            anchors.fill: parent
            text: cards.detailState.editing ? cards.detailState.editDraft : (cards.detailState.value ? (cards.detailState.value.text || "") : "")
            color: Ui.Theme.text
            selectionColor: Ui.Theme.selected
            selectedTextColor: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            readOnly: !cards.detailState.editing || cards.detailState.saveInFlight || cards.detailState.editBeginPending
            selectByMouse: true
            onVisibleChanged: if (!visible) focus = false
            onActiveFocusChanged: if (cards.directTextEdit)
                cards.detailState.setEditorFocused(activeFocus)
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
            visible: !cards.detailState.thumbnail && (!cards.detailState.value || cards.detailState.value.text === null)
            text: qsTr("Binary preview is unavailable")
            font.pixelSize: Ui.Theme.fontSizeBody
        }
    }

    Ui.DetailColumnCard {
        objectName: "clipboardInfoCard"
        visible: cards.selectedTab === "info"
        title: qsTr("Info")
        height: Math.max(250, cards.height)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 96

            Ui.DetailGrid {
                anchors.fill: parent
                entries: [
                    {
                        label: "Type",
                        value: cards.entry.kind || "—"
                    },
                    {
                        label: "MIME",
                        value: cards.entry.mime || "—"
                    },
                    {
                        label: "Size",
                        value: Ui.Format.bytes(cards.entry.byte_size)
                    },
                    {
                        label: "Dimensions",
                        value: cards.imageFacts ? cards.imageFacts.width + " × " + cards.imageFacts.height : "—"
                    }
                ]
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Ui.Theme.border
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            text: "Files"
            color: Ui.Theme.mutedText
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Ui.ThemeText {
                anchors.fill: parent
                visible: cards.files.length === 0
                text: qsTr("No associated files")
                color: Ui.Theme.mutedText
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

                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: fileRow.modelData.display_name
                        color: fileRow.modelData.exists ? Ui.Theme.text : Ui.Theme.danger
                        elide: Text.ElideMiddle
                    }
                    Ui.ThemeText {
                        text: fileRow.modelData.operation === "cut" ? "Move" : "Copy"
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
            }
        }
    }
}
