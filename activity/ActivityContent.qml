pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ActivityController controller
    property date now
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        Row {
            width: parent.width
            height: 42
            spacing: Ui.Theme.spacingSm

            Text {
                width: parent.width - headerActions.width - Ui.Theme.spacingSm
                anchors.verticalCenter: parent.verticalCenter
                text: "Activity"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }

            Row {
                id: headerActions
                height: parent.height
                spacing: Ui.Theme.spacingSm
                ActivityHeaderButton { label: "Today"; onTriggered: content.controller.goToToday() }
                ActivityHeaderButton { label: content.controller.activity.syncing ? "Syncing…" : "Refresh"; onTriggered: content.controller.refresh() }
            }
        }

        Rectangle {
            visible: content.controller.lastError.length > 0
            width: parent.width
            height: visible ? errorText.implicitHeight + 18 : 0
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.dangerBackground
            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: 9
                text: content.controller.lastError
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Row {
            width: parent.width
            height: parent.height - y
            spacing: Ui.Theme.spacingMd

            ActivityCalendarPane {
                controller: content.controller
                uiScale: content.uiScale
                now: content.now
            }

            ActivityAgendaPane {
                width: parent.width - x - rightPane.width - Ui.Theme.spacingMd
                controller: content.controller
            }

            ActivityOverviewPane {
                id: rightPane
                controller: content.controller
                uiScale: content.uiScale
                now: content.now
            }
        }
    }

    Shortcut { sequence: "Left"; onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() - 1)) }
    Shortcut { sequence: "Right"; onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() + 1)) }
    Shortcut { sequence: "PageUp"; onActivated: content.controller.shiftMonth(-1) }
    Shortcut { sequence: "PageDown"; onActivated: content.controller.shiftMonth(1) }
    Shortcut { sequence: "T"; onActivated: content.controller.goToToday() }
    Shortcut { sequence: "F5"; onActivated: content.controller.refresh() }

    Connections {
        target: content.controller
        function onFocusTodoInputRequested() { rightPane.focusTodoInput(); }
    }

    Component.onCompleted: now = new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: content.now = new Date()
    }
}
