pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property AgendaCalendarController controller
    readonly property AgendaContent agendaContent: agenda
    readonly property AgendaCalendarGrid calendarGrid: calendar
    clip: true
    Accessible.role: Accessible.Grouping
    Accessible.name: qsTr("Calendar")
    Accessible.description: controller.composition.supported ? "" : qsTr("Work area is below the supported calendar/list size")
    Connections {
        target: content.Window.window
        function onActiveFocusItemChanged(): void {
            if (!content.controller.uiActive || content.controller.uiSuspending) return;
            let item = content.Window.window.activeFocusItem;
            while (item) {
                if (item === agenda) { content.controller.focusRegion = "agenda"; return; }
                if (item === calendar) { content.controller.focusRegion = "calendar"; return; }
                item = item.parent;
            }
        }
    }
    Item {
        id: routeBar
        width: parent.width
        height: visible ? Ui.Theme.secondaryActionHeight : 0
        visible: content.controller.dayVisible
        Ui.FlatIconButton {
            objectName: "agendaReturnCalendar"
            height: parent.height
            width: height
            accessibleName: backCommand.accessibleName
            icon: "arrow_back"
            activeFocusOnTab: false
            enabled: backCommand.enabled
            onClicked: backCommand.activate()
        }
        Text {
            objectName: "agendaSelectedDay"
            anchors.left: parent.left
            anchors.leftMargin: routeBar.height + Ui.Theme.spacingMd
            anchors.right: parent.right
            anchors.rightMargin: Ui.Theme.contentMargin
            anchors.verticalCenter: parent.verticalCenter
            text: content.controller.selectedDate ? Qt.formatDate(new Date(content.controller.selectedDate + "T12:00:00"), "dddd, d MMMM yyyy") : ""
            elide: Text.ElideRight
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
    AgendaCalendarGrid {
        id: calendar
        anchors.fill: undefined
        controller: content.controller
        width: content.controller.composition.calendarWidth
        y: routeBar.height
        height: parent.height - y
        visible: content.controller.composition.calendarVisible
        inputBlocked: agenda.detailsNavigation.popupOpen || !content.controller.composition.supported
    }
    // This is the very same provider surface, not a calendar-local list or
    // inspector. It stays instantiated while fit changes to retain native drafts.
    AgendaContent {
        id: agenda
        controller: content.controller.agendaController
        anchors.fill: undefined
        x: calendar.visible ? calendar.width + content.controller.agendaController.detailsGapWidth : 0
        width: controller.currentWindowWidth
        y: routeBar.height
        height: parent.height - y
        visible: content.controller.dayVisible
        hostCommands: returnCommands
        hostNavigationEnabled: visible && content.controller.focusRegion === "agenda"
            && !calendar.dateNavigation.activeFocus && !calendar.detailsNavigation.activeFocus
    }
    Ui.CommandGroup {
        id: returnCommands
        visible: content.controller.dayVisible
        Ui.ActionControl {
            id: backCommand
            objectName: "agendaReturnCalendarCommand"
            accessibleName: qsTr("Return to calendar")
            activeFocusOnTab: false
            accessKey: "B"
            enabled: !content.controller.navigationBlocked && !agenda.detailsNavigation.popupOpen
            onClicked: content.controller.returnToCalendar()
        }
    }
}
