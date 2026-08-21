pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: card

    required property var notification
    required property BarController controller
    readonly property var actions: Array.isArray(notification.actions)
        ? notification.actions.filter(function (action) { return !card.isReplyAction(action); }) : []
    readonly property var replyAction: Array.isArray(notification.actions)
        ? notification.actions.find(function (action) { return card.isReplyAction(action); }) || null
        : null
    readonly property int urgency: notification.hints ? Number(notification.hints.urgency || 0) : 0
    readonly property string iconSource: resolveIconSource()

    function isReplyAction(action: var): bool {
        const key = String(action && action.key || "").toLowerCase();
        return key.indexOf("reply") >= 0;
    }

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
            }

            Column {
                id: headingColumn
                width: parent.width - 40 - dismissButton.width - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width
                    text: card.notification.summary || card.notification.app_name || "Notification"
                    color: Ui.Theme.text
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    width: parent.width
                    visible: text.length > 0
                    text: card.notification.app_name || ""
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }

            Ui.FlatIconButton {
                id: dismissButton
                width: 30
                height: 30
                icon: "󰅖"
                accessibleName: "Dismiss notification"
                onClicked: card.controller.dismissNotification(card.notification.id)
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: card.notification.body || ""
            textFormat: Text.PlainText
            color: Ui.Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }

        Row {
            width: parent.width
            visible: card.actions.length > 0
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: card.actions
                Ui.ActionButton {
                    required property var modelData
                    width: Math.max(74, Math.min(150, String(modelData.label || "Action").length * 8 + 24))
                    height: 34
                    label: modelData.label || "Action"
                    onClicked: card.controller.invokeNotificationAction(
                        card.notification.id, modelData.key)
                }
            }
        }

        Row {
            width: parent.width
            visible: card.replyAction !== null
            spacing: Ui.Theme.spacingSm
            Ui.TextField {
                id: replyField
                width: parent.width - replyButton.width - parent.spacing
                height: 36
                placeholder: "Reply…"
                maximumLength: 4096
                onAccepted: replyButton.sendReply()
            }
            Ui.ActionButton {
                id: replyButton
                width: 68
                height: 36
                label: "Send"
                enabled: replyField.text.trim().length > 0
                function sendReply(): void {
                    const text = replyField.text.trim();
                    if (text.length === 0)
                        return;
                    if (card.controller.replyNotification(card.notification.id, text))
                        replyField.text = "";
                }
                onClicked: sendReply()
            }
        }
    }
}
