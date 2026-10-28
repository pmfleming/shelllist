pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: editor
    required property AgendaController controller
    objectName: "agendaCreateEditor"
    revealFocusedControl: true
    Ui.FormField {
        width: parent.width
        label: qsTr("Title")
        Ui.TextField {
            objectName: "agendaCreateTitle"
            Layout.fillWidth: true
            enabled: !editor.controller.mutationBusy && !editor.controller.scheduleParsing
            text: editor.controller.createDraft.title
            onEdited: function(value) { editor.controller.createDraft = Object.assign({}, editor.controller.createDraft, {title: value}); }
        }
    }
    Ui.FormField {
        width: parent.width
        label: qsTr("Type")
        Ui.SegmentedControl {
            objectName: "agendaCreateKind"
            Layout.fillWidth: true
            enabled: !editor.controller.mutationBusy && !editor.controller.scheduleParsing
            iconOnly: true
            options: [{value: "task", icon: "checklist", label: qsTr("Task")}, {value: "event", icon: "calendar_month", label: qsTr("Event")}]
            value: editor.controller.createDraft.kind
            onSelected: function(value) { editor.controller.createDraft = Object.assign({}, editor.controller.createDraft, {kind: value}); }
        }
    }
    AgendaScheduleEditor {
        width: parent.width
        enabled: !editor.controller.mutationBusy && !editor.controller.scheduleParsing
        schedule: editor.controller.createDraft.schedule
        initialRaw: editor.controller.createScheduleRaw
        onChanged: function(value) { editor.controller.createScheduleRaw = value; }
    }
}
