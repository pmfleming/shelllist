pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PromptDialog {
    id: dialog
    required property AgendaController controller
    objectName: "agendaCollectionDialog"
    visible: controller.collectionOpen
    title: controller.collectionKey === "links" ? qsTr("Add link") : qsTr("Add checklist step")
    inputLabel: controller.collectionKey === "links" ? qsTr("Label") : qsTr("Step")
    inputText: controller.collectionText
    actionsVisible: true
    inlineHeaderActions: true
    actionSummaryVisible: false
    instruction: ""
    acceptLabel: qsTr("Add")
    acceptEnabled: !controller.mutationBusy && !!inputText.trim() && (controller.collectionKey !== "links" || !!controller.collectionUrl.trim())
    onInputEdited: function(value) { controller.collectionText = value; }
    onAccepted: controller.addCollection()
    onCancelled: controller.collectionOpen = false
    Ui.FormField {
        Layout.fillWidth: true
        visible: dialog.controller.collectionKey === "links"
        label: qsTr("URL")
        Ui.TextField {
            objectName: "agendaNewLinkUrl"
            Layout.fillWidth: true
            text: dialog.controller.collectionUrl
            onEdited: function(value) { dialog.controller.collectionUrl = value; }
        }
    }
}
