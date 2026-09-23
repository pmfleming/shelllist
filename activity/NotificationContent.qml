pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property NotificationController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        Ui.ChooserHeader {
            id: header
            objectName: "notificationHeader"
            width: parent.width
            height: scaled(Ui.Theme.headerHeight)
            uiScale: content.uiScale
            icon: ""
            iconActionEnabled: !content.controller.screenshotInFlight
            iconAccessibleName: "Copy Notifications panel screenshot"
            filterText: content.controller.filterText
            placeholder: content.controller.tab === "history" ? "Search loaded history…" : "Search notifications…"
            powered: content.controller.notificationState.notifications.dnd
            powerEnabled: content.controller.notificationState.notifications.available
            powerAccessibleName: "Do not disturb"
            powerAccessory: Component {
                NotificationDndDuration {
                    notificationState: content.controller.notificationState
                }
            }
            refreshing: content.controller.notificationState.historyLoading
            refreshEnabled: !refreshing && !content.controller.screenshotInFlight
            onIconClicked: content.controller.screenshotRequested()
            onFilterEdited: function (text) {
                content.controller.filterText = text;
            }
            onPowerRequested: content.controller.notificationState.setDndEnabled(!powered)
            onRefreshRequested: content.controller.refresh()
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Down) {
                    notifications.focusList();
                    event.accepted = true;
                }
            }
        }
        Row {
            id: toolbar
            readonly property NotificationState notificationState: content.controller.notificationState
            readonly property int activeCount: notificationState.activeNotifications.length
            width: parent.width
            height: Ui.Theme.compactControlHeight
            spacing: Ui.Theme.spacingSm

            Ui.FlatIconButton {
                id: backButton
                visible: content.controller.returnSurface === "activity"
                width: visible ? height : 0
                height: parent.height
                icon: "󰁍"
                accessibleName: "Back to agenda"
                toolTip: accessibleName
                onClicked: content.controller.goBack()
            }
            Ui.SegmentedControl {
                id: tabs
                objectName: "notificationTabs"
                width: Math.min(220, parent.width - backButton.width - trailing.width - parent.spacing * 2)
                height: parent.height
                value: content.controller.tab
                options: [
                    {
                        value: "active",
                        label: toolbar.activeCount > 0 ? "Active  " + toolbar.activeCount : "Active"
                    },
                    {
                        value: "history",
                        label: "History"
                    }
                ]
                onSelected: function (value) {
                    content.controller.tab = value;
                }
            }
            Ui.ThemeText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - backButton.width - tabs.width - trailing.width - parent.spacing * 3
                text: content.controller.screenshotStatus
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
            Row {
                id: trailing
                height: parent.height
                spacing: 2

                Row {
                    objectName: "notificationDraftIndicator"
                    visible: toolbar.notificationState.draftCount > 0
                    height: parent.height
                    rightPadding: Ui.Theme.spacingSm
                    spacing: Ui.Theme.spacingXs
                    Accessible.role: Accessible.StaticText
                    Accessible.name: draftTip.text
                    Controls.ToolTip {
                        id: draftTip
                        visible: draftHover.hovered
                        delay: 450
                        text: toolbar.notificationState.draftCount === 1 ? "1 unsent reply draft" : toolbar.notificationState.draftCount + " unsent reply drafts"
                    }
                    HoverHandler {
                        id: draftHover
                    }
                    Ui.GlyphLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "󰏫"
                        font.pixelSize: Ui.Theme.iconSizeSmall
                    }
                    Ui.ThemeText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: String(toolbar.notificationState.draftCount)
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                }
                Ui.FlatIconButton {
                    objectName: "notificationClearAll"
                    visible: content.controller.tab === "active"
                    width: visible ? height : 0
                    height: parent.height
                    icon: "󰎟"
                    enabled: toolbar.activeCount > 0
                    accessibleName: "Dismiss all active notifications"
                    toolTip: accessibleName
                    onClicked: toolbar.notificationState.clearNotifications()
                }
                Ui.FlatIconButton {
                    id: closeButton
                    width: height
                    height: parent.height
                    icon: "󰅖"
                    accessibleName: "Close"
                    toolTip: accessibleName
                    onClicked: content.controller.closeWindowRequested()
                }
            }
        }
        ActivityNotificationsPane {
            id: notifications
            width: parent.width
            height: parent.height - y
            controller: content.controller
        }
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested(): void {
            header.focusSearch();
        }
    }
    // No printable single-key shortcuts: replies and search own their typing.
    Shortcut {
        sequence: "Escape"
        enabled: content.controller.uiActive
        onActivated: content.controller.goBack()
    }
    Shortcut {
        sequence: "F5"
        enabled: content.controller.uiActive && !content.controller.screenshotInFlight
        onActivated: content.controller.refresh()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.uiActive
        onActivated: content.controller.tab = content.controller.tab === "active" ? "history" : "active"
    }
}
