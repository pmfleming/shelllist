pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property NotificationController controller
    readonly property real uiScale: Ui.Theme.densityScale(height,
        controller.contentVerticalMargin)

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
            placeholder: content.controller.tab === "history"
                ? "Search loaded history…" : "Search notifications…"
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
            onFilterEdited: function (text) { content.controller.filterText = text; }
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
            width: parent.width
            height: 34
            spacing: Ui.Theme.spacingSm

            Ui.FlatIconButton {
                id: backButton
                visible: content.controller.returnSurface === "activity"
                width: visible ? 34 : 0
                height: 34
                icon: "󰁍"
                accessibleName: "Back to agenda"
                toolTip: accessibleName
                onClicked: content.controller.goBack()
            }
            Ui.ThemeText {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - backButton.width - closeButton.width
                    - parent.spacing * (backButton.visible ? 2 : 1)
                text: content.controller.screenshotStatus || "Notifications · DND "
                    + (content.controller.notificationState.notifications.dnd ? "on" : "off")
                elide: Text.ElideRight
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
            Ui.FlatIconButton {
                id: closeButton
                width: 34
                height: 34
                icon: "󰅖"
                accessibleName: "Close notifications (drafts retained)"
                toolTip: accessibleName
                onClicked: content.controller.closeWindowRequested()
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
        function onFocusSearchRequested(): void { header.focusSearch(); }
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
