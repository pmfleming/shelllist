pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Column {
    id: section
    required property ActivityController controller
    required property real uiScale
    width: parent.width
    spacing: Ui.Theme.spacingSm
    function focusInput(): void {
        todoInput.focusInput(false);
    }
    function addTodo(): void {
        if (controller.todoDraft.trim().length > 0 && controller.createTodo(controller.todoDraft))
            controller.todoDraft = "";
    }
    Ui.ThemeText {
        text: qsTr("Todos")
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Ui.FormField {
        width: parent.width
        label: qsTr("New todo")
        icon: "check"
        editor: todoInput
        Row {
            Layout.fillWidth: true
            height: Ui.Theme.formHeight
            spacing: Ui.Theme.spacingSm
            Ui.TextField {
                id: todoInput
                objectName: "activityTodoDraft"
                width: parent.width - addButton.width - parent.spacing
                height: parent.height
                placeholder: qsTr("Add for selected day")
                text: section.controller.todoDraft
                onEdited: function (value) {
                    section.controller.todoDraft = value;
                }
                onAccepted: section.addTodo()
            }
            Ui.FlatIconButton {
                id: addButton
                accessKey: "A"
                width: height
                height: parent.height
                icon: "+"
                accessibleName: qsTr("Add todo")
                onClicked: section.addTodo()
            }
        }
    }
    Ui.ContentState {
        objectName: "todoContentState"
        width: parent.width
        visible: section.controller.selectedTodos.length === 0
        compact: true
        active: section.controller.uiActive
        icon: "checklist"
        kind: section.controller.rangeReadError || section.controller.snapshotReadError ? "unavailable" : section.controller.rangeLoading || section.controller.backend.snapshotLoading ? "loading" : "empty"
        text: section.controller.rangeReadError || section.controller.snapshotReadError || (kind === "loading" ? qsTr("Loading todos…") : qsTr("No todos for this day"))
    }
    Ui.ScrollableListView {
        width: parent.width
        height: Math.min(230 * section.uiScale, section.controller.selectedTodos.length * 46)
        spacing: 5
        clip: true
        model: section.controller.selectedTodos
        delegate: Row {
            id: todoRow
            required property var modelData
            width: ListView.view.width
            height: Ui.Theme.controlHeight
            spacing: Ui.Theme.spacingSm
            Ui.ToggleRow {
                objectName: "todo::" + todoRow.modelData.id + "::completed"
                width: parent.width - deleteButton.width - parent.spacing
                height: parent.height
                title: String(todoRow.modelData.title || qsTr("Todo"))
                checked: !!todoRow.modelData.completed
                onClicked: section.controller.toggleTodo(todoRow.modelData)
            }
            Ui.FlatIconButton {
                id: deleteButton
                accessKey: "D"
                commandScope: todoRow
                objectName: "todo::" + todoRow.modelData.id + "::delete"
                width: height
                height: parent.height
                icon: "󰆴"
                accessibleName: qsTr("Delete %1").arg(todoRow.modelData.title || qsTr("todo"))
                onClicked: section.controller.deleteTodo(todoRow.modelData)
            }
        }
    }
}
