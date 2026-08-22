pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property real uiScale
    required property date now

    function focusTodoInput(): void { todos.focusInput(); }

    spacing: Ui.Theme.spacingMd

    Connections {
        target: pane.controller
        function onFocusTodoInputRequested() { pane.focusTodoInput(); }
    }

    Row {
        width: parent.width
        height: Math.max(350, parent.height * 0.56)
        spacing: Ui.Theme.spacingMd

        ActivityCalendarPane {
            width: Math.max(360, parent.width * 0.54)
            height: parent.height
            controller: pane.controller
            uiScale: pane.uiScale
            now: pane.now
        }

        ActivityAgendaPane {
            width: parent.width - x
            height: parent.height
            controller: pane.controller
        }
    }

    Rectangle {
        width: parent.width
        height: parent.height - y
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        ActivityTodoSection {
            id: todos
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            controller: pane.controller
            uiScale: pane.uiScale
        }
    }
}
