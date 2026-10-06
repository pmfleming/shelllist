pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.PanelSurface {
    id: content

    required property ActivityController controller
    chooserController: controller
    navigationContent: region === 0 || !controller.detailsOpen ? glance : (sectionLoader.item as Item)
    Connections {
        target: content.controller
        function onDetailsOpenChanged(): void {
            content.region = content.controller.detailsOpen ? 1 : 0;
            if (content.controller.uiActive && !content.controller.uiSuspending)
                content.detailsNavigation.focusContent(true);
        }
    }
    readonly property alias now: liveClock.now
    readonly property real uiScale: 1

    Column {
        anchors.fill: parent
        anchors.margins: content.controller.contentMargin
        spacing: Ui.Theme.spacingMd

        Ui.DetailsHeader {
            width: parent.width
            uiScale: content.uiScale
            icon: "today"
            title: content.controller.detailsOpen ? "Activity  /  " + content.sectionTitle(content.controller.detailSection) : "Activity"
            actions: [
                {id: "today", label: qsTr("Today"), icon: "today", accessKey: "T", visible: !content.controller.detailsOpen, presentation: {group: "primary"}},
                {id: "overview", label: qsTr("Overview"), icon: "arrow_back", accessKey: "O", visible: content.controller.detailsOpen, presentation: {group: "toolbar"}},
                {id: "refresh", label: content.controller.activity.syncing ? qsTr("Syncing…") : qsTr("Refresh"), icon: "refresh", accessKey: "R", enabled: !content.controller.activity.syncing, presentation: {group: "toolbar"}}
            ]
            onActionTriggered: function(actionId) {
                if (actionId === "today") content.controller.goToToday();
                else if (actionId === "overview") content.controller.closeSection();
                else if (actionId === "refresh") content.controller.refresh();
            }
        }

        Rectangle {
            visible: content.controller.lastError.length > 0
            width: parent.width
            height: visible ? errorText.implicitHeight + 18 : 0
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.dangerBackground
            Ui.ThemeText {
                id: errorText
                anchors.fill: parent
                anchors.margins: 9
                text: content.controller.lastError
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Row {
            width: parent.width
            height: parent.height - y
            spacing: 0

            ActivityGlancePane {
                id: glance
                objectName: "activityGlancePane"
                width: content.controller.listPaneWidth
                height: parent.height
                controller: content.controller
                now: content.now
            }

            Item {
                visible: content.controller.detailsRendered
                width: content.controller.detailsPaneGapWidth
                height: parent.height
                Ui.VerticalDivider {}
            }

            Loader {
                id: sectionLoader
                visible: content.controller.detailsRendered
                width: content.controller.detailsPaneWidth
                height: parent.height
                clip: true
                active: content.controller.detailsRendered
                asynchronous: true
                sourceComponent: scheduleComponent
            }
        }
    }

    Component {
        id: scheduleComponent
        ActivitySchedulePane {
            controller: content.controller
            uiScale: content.uiScale
            now: content.now
        }
    }

    function sectionTitle(section: string): string {
        return "Calendar · Agenda · Todo";
    }

    Shortcut {
        sequence: "Ctrl+Left"
        enabled: content.controller.uiActive && content.controller.detailsOpen && content.controller.detailSection === "schedule"
        onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() - 1))
    }
    Shortcut {
        sequence: "Ctrl+Right"
        enabled: content.controller.uiActive && content.controller.detailsOpen && content.controller.detailSection === "schedule"
        onActivated: content.controller.selectDate(new Date(content.controller.selectedDate.getFullYear(), content.controller.selectedDate.getMonth(), content.controller.selectedDate.getDate() + 1))
    }
    Shortcut {
        sequence: "Ctrl+PageUp"
        enabled: content.controller.uiActive && content.controller.detailSection === "schedule"
        onActivated: content.controller.shiftMonth(-1)
    }
    Shortcut {
        sequence: "Ctrl+PageDown"
        enabled: content.controller.uiActive && content.controller.detailSection === "schedule"
        onActivated: content.controller.shiftMonth(1)
    }
    Shortcut {
        sequence: "Ctrl+2"
        enabled: content.controller.uiActive
        onActivated: content.controller.openSection("schedule")
    }
    Shortcut {
        sequence: "Ctrl+T"
        enabled: content.controller.uiActive
        onActivated: content.controller.goToToday()
    }
    Shortcut {
        sequence: "F5"
        enabled: content.controller.uiActive
        onActivated: content.controller.refresh()
    }

    Ui.LiveClock {
        id: liveClock
        active: content.controller.uiActive
    }
}
