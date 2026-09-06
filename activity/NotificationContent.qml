pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property NotificationController controller

    Column {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        Row {
            width: parent.width
            height: 42
            spacing: Ui.Theme.spacingSm

            Ui.FlatIconButton {
                id: backButton
                visible: content.controller.returnSurface === "activity"
                width: visible ? 34 : 0
                height: 34
                icon: "󰁍"
                accessibleName: "Back to Activity"
                toolTip: accessibleName
                onClicked: content.controller.goBack()
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - backButton.width - closeButton.width
                    - parent.spacing * (backButton.visible ? 2 : 1)
                text: "Notifications"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
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
            width: parent.width
            height: parent.height - y
            controller: content.controller
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
        enabled: content.controller.uiActive
        onActivated: content.controller.refresh()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.uiActive
        onActivated: content.controller.tab = content.controller.tab === "active" ? "history" : "active"
    }
}
