pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: row

    required property var record
    required property ActivityController controller
    readonly property var notification: record.notification || ({})
    readonly property bool active: controller.isNotificationActive(notification.id)
    readonly property var actions: Array.isArray(notification.actions)
        ? notification.actions.filter(function (action) { return !row.isReplyAction(action); }) : []
    readonly property var replyAction: Array.isArray(notification.actions)
        ? notification.actions.find(function (action) { return row.isReplyAction(action); }) || null
        : null

    function isReplyAction(action: var): bool {
        return String(action && action.key || "").toLowerCase().indexOf("reply") >= 0;
    }

    function iconSource(): string {
        const hints = notification.hints || ({});
        const candidate = String(hints.image_path || notification.app_icon || "");
        if (candidate.startsWith("/"))
            return "file://" + candidate;
        if (candidate.startsWith("file://"))
            return candidate;
        return Quickshell.iconPath(candidate || "dialog-information", "dialog-information");
    }

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: Math.max(78, historyContent.implicitHeight + Ui.Theme.spacingMd * 2)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surfaceRaised
    border.color: active ? Ui.Theme.withAlpha(Ui.Theme.accent, 0.48) : Ui.Theme.border
    opacity: active ? 1 : Ui.Theme.readOnlyOpacity

    Column {
        id: historyContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Ui.Theme.spacingMd
        }
        spacing: Ui.Theme.spacingSm

        Row {
            width: parent.width
            height: Math.max(34, titleColumn.implicitHeight)
            spacing: Ui.Theme.spacingSm
            Image {
                width: 32
                height: 32
                source: row.iconSource()
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Column {
                id: titleColumn
                width: parent.width - 32 - (row.active ? dismissButton.width + parent.spacing * 2 : parent.spacing)
                spacing: 2
                Text {
                    width: parent.width
                    text: row.notification.summary || row.notification.app_name || "Notification"
                    color: Ui.Theme.text
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeBody
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    width: parent.width
                    text: (row.notification.app_name || "") + "  "
                        + Qt.formatDateTime(new Date(Number(row.notification.created_unix_ms || 0)), "d MMM HH:mm")
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
            Ui.FlatIconButton {
                id: dismissButton
                visible: row.active
                width: visible ? 28 : 0
                height: 28
                icon: "󰅖"
                accessibleName: "Dismiss notification"
                onClicked: row.controller.dismissNotification(row.notification.id)
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: row.notification.body || ""
            textFormat: Text.PlainText
            color: Ui.Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
        }

        Row {
            width: parent.width
            visible: row.active && row.actions.length > 0
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: row.actions
                Ui.ActionButton {
                    required property var modelData
                    width: Math.max(68, Math.min(130,
                        String(modelData.label || "Action").length * 7 + 22))
                    height: 32
                    label: modelData.label || "Action"
                    onClicked: row.controller.invokeNotificationAction(
                        row.notification.id, modelData.key)
                }
            }
        }

        Ui.NotificationReplyRow {
            visible: row.active && row.replyAction !== null
            notificationId: Number(row.notification.id)
            submitReply: function (id, text) {
                return row.controller.replyNotification(id, text);
            }
        }
    }
}
