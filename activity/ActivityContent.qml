pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ActivityController controller
    property date now
    readonly property real uiScale: Ui.Theme.densityScale(height,
        controller.contentVerticalMargin)

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        Row {
            width: parent.width
            height: 42
            spacing: Ui.Theme.spacingSm

            Ui.FlatIconButton {
                id: activityIcon
                width: 34
                height: 34
                anchors.verticalCenter: parent.verticalCenter
                icon: "󰃭"
                iconSize: Ui.Theme.iconSizeLarge
                flatIconColor: Ui.Theme.accent
                enabled: !content.controller.screenshotInFlight
                accessibleName: "Copy Activity panel screenshot"
                toolTip: content.controller.screenshotStatus.length > 0
                    ? content.controller.screenshotStatus
                    : "Activity · click to copy a screenshot"
                onClicked: content.controller.screenshotRequested()
            }

            Text {
                width: parent.width - activityIcon.width - headerActions.width
                    - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                text: content.controller.detailsOpen
                    ? "Activity  /  " + content.sectionTitle(content.controller.detailSection)
                    : "Activity"
                color: Ui.Theme.text
                elide: Text.ElideRight
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }

            Row {
                id: headerActions
                height: parent.height
                spacing: Ui.Theme.spacingSm
                ActivityHeaderButton {
                    visible: content.controller.detailsOpen
                    label: "Overview"
                    onTriggered: content.controller.closeSection()
                }
                ActivityHeaderButton {
                    label: "Today"
                    onTriggered: content.controller.goToToday()
                }
                ActivityHeaderButton {
                    label: content.controller.activity.syncing ? "Syncing…" : "Refresh"
                    onTriggered: content.controller.refresh()
                }
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
            spacing: 0

            Loader {
                id: detailLoader
                visible: content.controller.detailsRendered
                width: content.controller.detailsPaneWidth
                height: parent.height
                clip: true
                active: content.controller.detailsRendered
                sourceComponent: content.controller.detailSection === "weather"
                    ? weatherComponent : content.controller.detailSection === "notifications"
                        ? notificationsComponent : scheduleComponent
            }

            Item {
                visible: content.controller.detailsRendered
                width: content.controller.detailsPaneGapWidth
                height: parent.height
                Ui.VerticalDivider {}
            }

            ActivityGlancePane {
                width: content.controller.listPaneWidth
                height: parent.height
                controller: content.controller
                now: content.now
            }
        }
    }

    Component {
        id: weatherComponent
        ActivityWeatherPane {
            controller: content.controller
            now: content.now
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

    Component {
        id: notificationsComponent
        ActivityNotificationsPane { controller: content.controller }
    }

    function sectionTitle(section: string): string {
        if (section === "weather")
            return "Local time · Weather";
        if (section === "notifications")
            return "Notifications";
        return "Calendar · Agenda · Todo";
    }

    Shortcut {
        sequence: "Escape"
        onActivated: content.controller.dismissNavigation()
    }
    Shortcut {
        sequence: "Left"
        enabled: content.controller.detailsOpen
            && content.controller.detailSection === "schedule"
        onActivated: content.controller.selectDate(new Date(
            content.controller.selectedDate.getFullYear(),
            content.controller.selectedDate.getMonth(),
            content.controller.selectedDate.getDate() - 1))
    }
    Shortcut {
        sequence: "Right"
        enabled: content.controller.detailsOpen
            && content.controller.detailSection === "schedule"
        onActivated: content.controller.selectDate(new Date(
            content.controller.selectedDate.getFullYear(),
            content.controller.selectedDate.getMonth(),
            content.controller.selectedDate.getDate() + 1))
    }
    Shortcut {
        sequence: "PageUp"
        enabled: content.controller.detailSection === "schedule"
        onActivated: content.controller.shiftMonth(-1)
    }
    Shortcut {
        sequence: "PageDown"
        enabled: content.controller.detailSection === "schedule"
        onActivated: content.controller.shiftMonth(1)
    }
    Shortcut { sequence: "1"; onActivated: content.controller.openSection("weather") }
    Shortcut { sequence: "2"; onActivated: content.controller.openSection("schedule") }
    Shortcut { sequence: "3"; onActivated: content.controller.openSection("notifications") }
    Shortcut { sequence: "T"; onActivated: content.controller.goToToday() }
    Shortcut { sequence: "F5"; onActivated: content.controller.refresh() }

    Component.onCompleted: now = new Date()

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: content.now = new Date()
    }
}
