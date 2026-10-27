pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PromptDialog {
    id: dialog
    required property AgendaController controller
    objectName: "agendaCreateDialog"
    visible: controller.createOpen
    title: qsTr("Create item")
    icon: "add"
    inputText: controller.createDraft.title
    inputLabel: qsTr("Title")
    actionsVisible: true
    inlineHeaderActions: true
    actionSummaryVisible: false
    instruction: ""
    acceptLabel: qsTr("Create")
    acceptEnabled: !controller.mutationBusy && !controller.scheduleParsing && !!inputText.trim()
    onInputEdited: function(value) { controller.pendingSchedule = null; controller.createDraft = Object.assign({}, controller.createDraft, {title: value}); }
    onAccepted: controller.create()
    onCancelled: controller.createOpen = false
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Type")
        Ui.DropDownList {
            objectName: "agendaCreateKind"
            Layout.fillWidth: true
            options: [{value: "task", label: qsTr("Task")}, {value: "event", label: qsTr("Event")}]
            value: dialog.controller.createDraft.kind
            onSelected: function(value) { dialog.controller.createDraft = Object.assign({}, dialog.controller.createDraft, {kind: value}); }
        }
    }
    Loader {
        id: scheduleLoader
        Layout.fillWidth: true
        active: dialog.visible
        enabled: !dialog.controller.mutationBusy && !dialog.controller.scheduleParsing
        sourceComponent: Component {
            AgendaScheduleEditor {
                schedule: dialog.controller.createDraft.schedule
                onChanged: function(value) { dialog.controller.createScheduleRaw = value; }
            }
        }
    }
    Ui.FlatIconButton {
        visible: dialog.controller.failedOperation?.kind === "create"
        icon: "find_in_page"
        accessibleName: qsTr("Check creation outcome")
        enabled: !dialog.controller.receiptBusy && !dialog.controller.mutationBusy
        onClicked: dialog.controller.checkReceipt()
    }
}
