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

    Rectangle {
        width: parent.width
        height: 52
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Row {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingSm
            spacing: Ui.Theme.spacingSm
            ActivityHeaderButton {
                id: previousButton
                label: "‹"
                onTriggered: pane.controller.selectDate(new Date(
                    pane.controller.selectedDate.getFullYear(),
                    pane.controller.selectedDate.getMonth(),
                    pane.controller.selectedDate.getDate() - 1))
            }
            Text {
                width: parent.width - previousButton.width - nextWidth.width
                    - todayButton.width - parent.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(pane.controller.selectedDate, "dddd, d MMMM yyyy")
                color: Ui.Theme.text
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeHeading
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            ActivityHeaderButton {
                id: nextWidth
                label: "›"
                onTriggered: pane.controller.selectDate(new Date(
                    pane.controller.selectedDate.getFullYear(),
                    pane.controller.selectedDate.getMonth(),
                    pane.controller.selectedDate.getDate() + 1))
            }
            ActivityHeaderButton {
                id: todayButton
                label: "Today"
                onTriggered: pane.controller.goToToday()
            }
        }
    }

    Row {
        width: parent.width
        height: parent.height - y
        spacing: Ui.Theme.spacingMd

        ActivityAgendaPane {
            width: parent.width * 0.62
            height: parent.height
            controller: pane.controller
        }

        Rectangle {
            width: parent.width - x
            height: parent.height
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
}
