pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property real uiScale
    required property date now

    function focusTodoInput(): void {
        todos.focusInput();
    }

    spacing: Ui.Theme.spacingMd

    Connections {
        target: pane.controller
        function onFocusTodoInputRequested() {
            pane.focusTodoInput();
        }
    }

    Rectangle {
        width: parent.width
        height: Ui.Theme.formHeight
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surface
        border.width: 0

        Row {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingSm
            spacing: Ui.Theme.spacingSm
            ActivityHeaderButton {
                id: previousButton
                objectName: "activityPreviousDay"
                label: qsTr("Previous day")
                icon: "chevron_left"
                onTriggered: pane.controller.selectDate(new Date(pane.controller.selectedDate.getFullYear(), pane.controller.selectedDate.getMonth(), pane.controller.selectedDate.getDate() - 1))
            }
            Ui.ThemeText {
                width: parent.width - previousButton.width - nextWidth.width - todayButton.width - parent.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(pane.controller.selectedDate, "dddd, d MMMM yyyy")
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                font.pixelSize: Ui.Theme.groupHeadingSize
                font.weight: Ui.Theme.groupHeadingWeight
            }
            ActivityHeaderButton {
                id: nextWidth
                objectName: "activityNextDay"
                label: qsTr("Next day")
                icon: "chevron_right"
                onTriggered: pane.controller.selectDate(new Date(pane.controller.selectedDate.getFullYear(), pane.controller.selectedDate.getMonth(), pane.controller.selectedDate.getDate() + 1))
            }
            ActivityHeaderButton {
                id: todayButton
                label: "Today"
                icon: "today"
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

        Ui.DetailCard {
            width: parent.width - x
            height: parent.height

            ActivityTodoSection {
                id: todos
                anchors.fill: parent
                controller: pane.controller
                uiScale: pane.uiScale
            }
        }
    }
}
