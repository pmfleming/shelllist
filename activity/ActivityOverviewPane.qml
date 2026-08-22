pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: pane

    required property ActivityController controller
    required property real uiScale
    required property date now

    function focusTodoInput(): void { todos.focusInput(); }

    width: 300 * pane.uiScale
    height: parent.height
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm
        ActivityTodoSection {
            id: todos
            controller: pane.controller
            uiScale: pane.uiScale
        }

        ActivityStatusSection {
            controller: pane.controller
            now: pane.now
        }
    }
}
