pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content
    required property AgendaController controller
    readonly property real preferredWidth: controller.currentWindowWidth
    readonly property bool supported: preferredWidth + 2 * controller.geometry.edgeMargin <= controller.geometry.availableWidth
    property Item hostCommands: null
    Binding {
        target: content.controller.navigation
        property: "blocked"
        value: content.controller.navigationBlocked || !content.supported
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: content.hostCommands
        property: "parent"
        value: commands
        when: content.hostCommands !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
    function focusInitial(): void { if (listItem) listItem.focusSearch(); }
    function suspendSurface(): void { detailsNavigation.suspendView(); }
    chooserController: controller
    feedbackScope: content
    navigationEnabled: supported && !controller.modalOpen
    commandsWithoutDetails: true
    additionalCommandItem: commands
    Rectangle {
        anchors.fill: parent
        z: 100
        visible: !content.supported
        color: Ui.Theme.window
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: function(event) { event.accepted = true; }
        }
        Ui.CenteredMessage {
            width: Math.min(parent.width, content.controller.geometry.availableWidth)
            height: parent.height
            text: qsTr("This work area is too narrow for the shared agenda layout.")
        }
    }
    Ui.CommandGroup {
        id: commands
        Ui.ActionControl {
            objectName: "agendaAddCommand"
            accessibleName: qsTr("Create item")
            accessKey: "A"
            enabled: content.navigationEnabled && !content.controller.mutationBusy && AgendaRepository.ready
            onClicked: content.controller.openCreation()
        }
        Ui.ActionControl {
            accessibleName: qsTr("Check saved operation outcome")
            accessKey: "K"
            enabled: content.navigationEnabled && !content.controller.detailsOpen && !!content.controller.failedOperation && !content.controller.receiptBusy
            onClicked: content.controller.checkReceipt()
        }
        Ui.ActionControl {
            accessibleName: qsTr("Agenda information")
            accessKey: "G"
            enabled: content.navigationEnabled
            onClicked: content.controller.settingsOpen = true
        }
    }
    Ui.FeedbackSource {
        text: content.controller.error || content.controller.detailError || (content.controller.mutationBusy ? qsTr("Saving agenda item…") : "")
        summaryText: text
        briefText: qsTr("Agenda needs attention")
        tone: content.controller.error || content.controller.detailError ? "error" : "info"
    }
    FontMetrics {
        id: sourceFeedbackMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.statusTextSize
    }
    Ui.FeedbackSource {
        objectName: "agendaSourceFeedback"
        active: content.controller.failingSourceCount > 0
        text: qsTr("%1 source issue(s) · %2").arg(content.controller.failingSourceCount).arg(content.controller.sourceError)
        summaryText: content.controller.sourceError
        // Native cause comes first. Elide presentation, never classify errors;
        // the full diagnostic/count remain accessible and in Information.
        briefText: sourceFeedbackMetrics.elidedText(content.controller.sourceError, Text.ElideRight, content.controller.listPaneWidth / 2)
        tone: "warning"
    }
    AgendaCreateDialog { controller: content.controller }
    Ui.ConfirmationDialog {
        objectName: "agendaRebaseDialog"
        visible: content.controller.rebaseTarget !== null
        title: qsTr("Apply saved draft to revision %1?").arg(content.controller.rebaseTarget?.item.revision || "")
        detail: qsTr("This explicitly replaces the saved field on the current item revision. Other current fields are preserved. Check the previous operation outcome first if it is uncertain.")
        acceptEnabled: content.controller.rebaseTarget?.draft.key === "task.completed" ? content.controller.canComplete(content.controller.rebaseTarget.item) : content.controller.canWrite(content.controller.rebaseTarget?.item)
        onAccepted: content.controller.confirmRebase()
        onCancelled: content.controller.rebaseTarget = null
    }
    Ui.ConfirmationDialog {
        objectName: "agendaDeleteDialog"
        visible: content.controller.deleteTarget !== null
        title: qsTr("Delete %1?").arg(content.controller.deleteTarget?.title || "")
        detail: qsTr("Permanently deletes this item and its notes, links and checklist.")
        acceptEnabled: !content.controller.mutationBusy
        onAccepted: content.controller.confirmDelete()
        onCancelled: content.controller.deleteTarget = null
    }
    Ui.PromptDialog {
        id: scheduleDialog
        objectName: "agendaScheduleDialog"
        visible: content.controller.scheduleOpen
        title: qsTr("Edit schedule")
        inputVisible: false
        actionsVisible: true
        inlineHeaderActions: true
        actionSummaryVisible: false
        instruction: ""
        acceptLabel: qsTr("Save schedule")
        acceptEnabled: !content.controller.mutationBusy && !content.controller.scheduleParsing
        // Enter belongs to the native editor; only explicit Save submits this
        // compound modal. A field Enter cannot accidentally commit the group.
        enterEnabled: false
        onAccepted: content.controller.saveSchedule()
        onCancelled: content.controller.scheduleOpen = false
        Loader {
            id: scheduleLoader
            Layout.fillWidth: true
            active: scheduleDialog.visible
            enabled: !content.controller.mutationBusy && !content.controller.scheduleParsing
            sourceComponent: Component {
                AgendaScheduleEditor {
                    schedule: content.controller.scheduleDraft
                    scheduleText: content.controller.scheduleText
                    onChanged: function(value) { content.controller.scheduleRaw = value; }
                }
            }
        }
        Ui.FlatIconButton {
            visible: content.controller.failedOperation?.key === "schedule"
            icon: "find_in_page"
            accessibleName: qsTr("Check schedule outcome")
            enabled: !content.controller.receiptBusy && !content.controller.mutationBusy
            onClicked: content.controller.checkReceipt()
        }
    }
    Ui.PromptDialog {
        objectName: "agendaSettingsDialog"
        visible: content.controller.settingsOpen
        title: qsTr("Agenda information")
        detail: qsTr("System timezone defines calendar membership. Local items are editable; imported calendars are read-only. Recurrence, reminders and attachments are not supported in this release.")
            + (content.controller.sourceError ? "\n" + qsTr("%1 source issue(s): %2").arg(content.controller.failingSourceCount).arg(content.controller.sourceError) : "")
        inputVisible: false
        actionsVisible: true
        acceptLabel: qsTr("Close")
        onAccepted: content.controller.settingsOpen = false
        onCancelled: content.controller.settingsOpen = false
    }
    AgendaCollectionDialog { controller: content.controller }
    listComponent: Component { AgendaListPane { controller: content.controller } }
    detailsComponent: Component { AgendaItemDetails { controller: content.controller; uiScale: content.uiScale } }
}
