pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: card

    required property var notification
    required property BarController controller
    property int groupCount: 1
    property bool breakoutVisible: false
    readonly property var actions: Ui.NotificationPresentation.standardActions(notification)
    readonly property var replyAction: Ui.NotificationPresentation.replyAction(notification)
    readonly property int urgency: notification.hints ? Number(notification.hints.urgency || 0) : 0
    readonly property string iconSource: resolveIconSource()
    property bool removing: false

    signal breakoutRequested

    function resolveIconSource(): string {
        const hints = notification.hints || ({});
        const candidate = String(hints.image_path || notification.app_icon || "");
        if (candidate.startsWith("/"))
            return "file://" + candidate;
        if (candidate.startsWith("file://"))
            return candidate;
        return candidate.length > 0
            ? Quickshell.iconPath(candidate, "dialog-information")
            : Quickshell.iconPath("dialog-information", "application-x-executable");
    }

    width: 390
    implicitHeight: Math.max(112, bodyColumn.implicitHeight + Ui.Theme.spacingMd * 2)
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.98)
    border.width: 1
    border.color: urgency >= 2 ? Ui.Theme.danger
        : (urgency === 1 ? Ui.Theme.withAlpha(Ui.Theme.accent, 0.58) : Ui.Theme.border)

    Ui.Elevation {
        anchors.fill: parent
        radius: card.radius
        level: 3
        z: -1
    }

    Column {
        id: bodyColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Ui.Theme.spacingMd
        }
        spacing: Ui.Theme.spacingSm

        Row {
            width: parent.width
            height: Math.max(40, headingColumn.implicitHeight)
            spacing: Ui.Theme.spacingSm

            Rectangle {
                width: 40
                height: 40
                radius: Ui.Theme.controlRadius
                color: Ui.Theme.input
                clip: true
                Image {
                    anchors.fill: parent
                    anchors.margins: 6
                    source: card.iconSource
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                Ui.GroupCountBadge {
                    count: card.groupCount
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                }
            }

            Column {
                id: headingColumn
                width: parent.width - 40 - breakoutButton.width - snoozeButton.width
                    - dismissButton.width - parent.spacing * (card.breakoutVisible ? 4 : 3)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Ui.ThemeText {
                    width: parent.width
                    text: card.notification.summary || card.notification.app_name || "Notification"
                    elide: Text.ElideRight
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Ui.ThemeText {
                    width: parent.width
                    visible: text.length > 0
                    text: card.notification.app_name || ""
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }

            Ui.FlatIconButton {
                id: breakoutButton
                visible: card.breakoutVisible
                width: visible ? 30 : 0
                height: 30
                icon: "󰅂"
                accessibleName: "Open notification center"
                toolTip: accessibleName
                onClicked: card.breakoutRequested()
            }

            Ui.FlatIconButton {
                id: snoozeButton
                width: 30
                height: 30
                icon: "󰒲"
                accessibleName: "Snooze notification for 15 minutes"
                toolTip: accessibleName
                onClicked: card.controller.snoozeNotification(card.notification.id, 15)
            }

            Ui.FlatIconButton {
                id: dismissButton
                width: 30
                height: 30
                icon: "󰅖"
                accessibleName: "Dismiss notification"
                onClicked: card.removing = true
            }
        }

        Ui.ThemeText {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body || ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Ui.NotificationActionList {
            width: parent.width
            actions: card.actions
            onTriggered: function (actionKey) {
                card.controller.invokeNotificationAction(card.notification.id, actionKey);
            }
        }

        Ui.NotificationReplyRow {
            visible: card.replyAction !== null
            notificationId: Number(card.notification.id)
            controlHeight: 36
            buttonWidth: 68
            readonly property var replyState: card.controller.notificationState
            readonly property var status: replyState
                ? replyState.replies[notificationId] || ({}) : ({})
            draftText: replyState ? String(replyState.drafts[notificationId] || "") : ""
            sending: status.pending === true
            errorText: status.error || ""
            onDraftEdited: function (text) {
                if (replyState) replyState.setDraft(notificationId, text);
            }
            submitReply: function (id, text) {
                return card.controller.replyNotification(id, text);
            }
        }
    }

    Ui.RemovalAnimation {
        targetItem: card
        removalRequested: card.removing
        finishRemoval: function () {
            card.controller.dismissNotification(card.notification.id);
        }
    }
}
