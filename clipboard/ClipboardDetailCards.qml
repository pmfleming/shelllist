pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: cards
    objectName: "clipboardDetailPage"

    required property ClipboardController controller
    readonly property ClipboardDetailsController detailState: controller.detailState
    readonly property var entry: detailState.value ? detailState.value.entry : (controller.selectedEntry || ({}))
    readonly property bool previewLoading: detailState.loading || detailState.thumbnailRequestId.length > 0 || (!!detailState.thumbnail && thumbnailImage.status !== Image.Ready && thumbnailImage.status !== Image.Error)
    readonly property string previewMessage: detailState.error || (previewLoading ? qsTr("Loading preview…") : (entry.kind === "image" ? qsTr("Image preview is unavailable") : qsTr("Binary preview is unavailable")))
    readonly property var files: detailState.value ? detailState.value.files : []
    readonly property var imageFacts: detailState.value ? detailState.value.image : null
    readonly property bool directTextEdit: entry.kind === "text"
    readonly property string selectedTab: controller.detailsTab
    viewMemory: controller.viewMemory
    memoryTab: selectedTab

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
        Ui.RecoveryActions {
            Layout.fillWidth: true
            enabled: !cards.controller.actionInFlight && !cards.detailState.editBeginPending
            retryAction.objectName: "retryClipboardEdit"
            discardAction.objectName: "discardClipboardEdit"
            discardAction.accessKey: "D"
            onRetryRequested: cards.detailState.retryEdit()
            onDiscardRequested: cards.detailState.discardFailedEdit()
        }
    }

    Ui.DetailCard {
        objectName: "clipboardDataCard"
        visible: cards.selectedTab === "data"
        title: cards.entry.kind ? cards.entry.kind.charAt(0).toUpperCase() + cards.entry.kind.slice(1) : "Clipboard item"
        height: Math.max(220, cards.height)

        Image {
            id: thumbnailImage
            objectName: "clipboardThumbnail"
            visible: !cards.detailState.loading && cards.detailState.error.length === 0 && !!cards.detailState.thumbnail && status === Image.Ready
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: true
            sourceSize.width: width
            sourceSize.height: height
            source: cards.detailState.thumbnail ? "file://" + cards.detailState.thumbnail.path : ""
        }
        Ui.TextEditor {
            objectName: "clipboardTextEditor"
            editingAllowed: cards.directTextEdit && !cards.detailState.saveInFlight && !cards.detailState.editBeginPending
            visible: !cards.previewLoading && cards.detailState.error.length === 0 && !cards.detailState.thumbnail && cards.detailState.value && cards.detailState.value.text !== null
            anchors.fill: parent
            text: cards.detailState.editing ? cards.detailState.editDraft : (cards.detailState.value ? (cards.detailState.value.text || "") : "")
            Accessible.name: qsTr("Clipboard text")
            Accessible.description: cards.detailState.editError || (cards.detailState.saveInFlight ? qsTr("Saving…") : "")
            errorText: cards.detailState.editError
            readOnly: !cards.detailState.editing || cards.detailState.saveInFlight || cards.detailState.editBeginPending
            selectByMouse: true
            onVisibleChanged: if (!visible)
                focus = false
            onActiveFocusChanged: if (cards.directTextEdit)
                cards.detailState.setEditorFocused(activeFocus)
            onEdited: function (value) {
                if (cards.directTextEdit)
                    cards.detailState.updateEditDraft(value);
                else
                    cards.detailState.editDraft = value;
            }
            onEditFinished: function (saved) {
                if (saved)
                    cards.detailState.finishDirectEdit();
                else if (cards.detailState.editError.length === 0)
                    cards.detailState.cancelEdit();
                else
                    cards.detailState.setEditorFocused(false); // Keep a previously submitted failed draft.
            }
            wrapMode: TextEdit.Wrap
        }
        Ui.CenteredMessage {
            objectName: "clipboardPreviewMessage"
            anchors.fill: parent
            visible: cards.detailState.error.length > 0 || cards.previewLoading || (!!cards.detailState.thumbnail ? thumbnailImage.status === Image.Error : (!cards.detailState.value || cards.detailState.value.text === null))
            text: cards.previewMessage
            color: cards.detailState.error.length > 0 ? Ui.Theme.danger : Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeBody
        }
    }

    Ui.DetailColumnCard {
        objectName: "clipboardInfoCard"
        visible: cards.selectedTab === "info"
        title: qsTr("Info")

        Ui.DetailGrid {
            objectName: "clipboardMetadata"
            Layout.fillWidth: true
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
            ].filter((row, index) => index < 3 || cards.entry.kind === "image")
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            visible: cards.detailState.loading || cards.detailState.error.length > 0
            text: cards.detailState.error || qsTr("Loading entry details…")
            color: cards.detailState.error.length > 0 ? Ui.Theme.danger : Ui.Theme.mutedText
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: cards.files.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Ui.Theme.border
        }

        Ui.ThemeText {
            objectName: "clipboardFilesHeading"
            visible: cards.files.length > 0
            Layout.fillWidth: true
            text: qsTr("Files")
            color: Ui.Theme.mutedText
        }

        Item {
            visible: cards.files.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(360, Math.max(Ui.Theme.controlHeight, fileList.contentHeight))

            Ui.ScrollableListView {
                id: fileList
                objectName: "clipboardFileList"
                anchors.fill: parent
                visible: cards.files.length > 0
                model: cards.files
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                delegate: RowLayout {
                    id: fileRow

                    required property var modelData
                    width: fileList.width
                    height: Math.max(Ui.Theme.controlHeight, fileName.implicitHeight + Ui.Theme.spacingSm)
                    spacing: Ui.Theme.spacingMd

                    Ui.ThemeText {
                        id: fileName
                        objectName: "clipboardFileName"
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: fileRow.modelData.display_name
                        color: fileRow.modelData.exists ? Ui.Theme.text : Ui.Theme.danger
                        wrapMode: Text.Wrap
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
