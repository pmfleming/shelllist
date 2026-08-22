pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: section

    required property ActivityController controller
    required property real uiScale

    width: parent.width
    spacing: Ui.Theme.spacingSm

    function focusInput(): void { todoInput.forceActiveFocus(); }

    Text {
        text: "Todos"
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Row {
        width: parent.width
        height: 36
        spacing: Ui.Theme.spacingSm
        Rectangle {
            width: parent.width - addTodo.width - parent.spacing
            height: parent.height
            radius: Ui.Theme.controlRadius
            color: Ui.Theme.input
            border.color: todoInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
            TextInput {
                id: todoInput
                anchors.fill: parent
                anchors.margins: 9
                color: Ui.Theme.inputText
                selectionColor: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
                clip: true
                onAccepted: {
                    if (text.trim().length > 0 && section.controller.createTodo(text))
                        text = "";
                }
            }
            Text {
                visible: todoInput.text.length === 0 && !todoInput.activeFocus
                anchors.fill: parent
                anchors.margins: 9
                text: "Add for selected day"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
            }
        }
        ActivityHeaderButton {
            id: addTodo
            label: "+"
            onTriggered: {
                if (todoInput.text.trim().length > 0
                        && section.controller.createTodo(todoInput.text))
                    todoInput.text = "";
            }
        }
    }
    Ui.ScrollableListView {
        width: parent.width
        height: Math.min(230 * section.uiScale, section.controller.selectedTodos.length * 46)
        spacing: 5
        clip: true
        model: section.controller.selectedTodos
        delegate: Rectangle {
            id: todoRow
            required property var modelData
            width: ListView.view.width
            height: 42
            radius: Ui.Theme.controlRadius
            color: Ui.Theme.surfaceRaised
            border.color: Ui.Theme.border
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.right: deleteTodo.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: (todoRow.modelData.completed ? "✓  " : "○  ") + todoRow.modelData.title
                color: todoRow.modelData.completed ? Ui.Theme.mutedText : Ui.Theme.text
                font.strikeout: todoRow.modelData.completed
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.controller.toggleTodo(todoRow.modelData)
                }
            }
            Text {
                id: deleteTodo
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: "×"
                color: Ui.Theme.danger
                font.pixelSize: 18
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.controller.deleteTodo(todoRow.modelData)
                }
            }
        }
    }
}
