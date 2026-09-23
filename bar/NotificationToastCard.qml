pragma ComponentBehavior: Bound

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
    readonly property var defaultAction: Ui.NotificationPresentation.defaultAction(notification)
    readonly property int urgency: Ui.NotificationPresentation.urgency(notification)
    readonly property var replyState: controller.notificationState
    readonly property var replyStatus: replyState ? replyState.replies[notification.id] || ({}) : ({})
    readonly property string draft: replyState ? String(replyState.drafts[notification.id] || "") : ""
    property bool replyOpen: false
    readonly property bool replyVisible: replyAction !== null && (replyOpen || draft.length > 0 || replyStatus.pending === true || String(replyStatus.error || "").length > 0)
    readonly property bool controlsRevealed: hover.hovered || replyVisible
    property double nowMs: Date.now()
    property bool removing: false

    signal breakoutRequested

    function activate(): void {
        if (defaultAction)
            controller.invokeNotificationAction(notification.id, defaultAction.key);
        else
            controller.openNotificationCenter(Ui.NotificationPresentation.groupKey(notification));
    }

    width: 390
    implicitHeight: bodyColumn.implicitHeight + Ui.Theme.spacingMd * 2
    radius: Ui.Theme.panelRadius
    color: urgency >= 2 ? Ui.Theme.mix(Ui.Theme.surfaceRaised, Ui.Theme.danger, 0.10) : Ui.Theme.withAlpha(Ui.Theme.surfaceRaised, 0.98)
    border.width: 1
    border.color: urgency >= 2 ? Ui.Theme.danger : Ui.Theme.border
    opacity: 1 - Math.max(0, x) / width * 0.7

    Behavior on x {
        enabled: !Ui.Theme.noAnimations && !swipe.drag.active
        NumberAnimation {
            duration: Ui.Theme.animationNormal
            easing.type: Ui.Theme.easingResponsive
        }
    }

    Ui.Elevation {
        anchors.fill: parent
        radius: card.radius
        level: 3
        z: -1
    }

    HoverHandler {
        id: hover
    }

    // Beneath the content: a click activates the card, a swipe right dismisses it.
    MouseArea {
        id: swipe
        objectName: "notificationToastSurface"
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        drag.target: card
        drag.axis: Drag.XAxis
        drag.minimumX: 0
        drag.maximumX: card.width
        drag.threshold: 12
        onReleased: {
            if (card.x > card.width * 0.3)
                card.removing = true;
            else
                card.x = 0;
        }
        onClicked: if (card.x < 2)
            card.activate()
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
            spacing: Ui.Theme.spacingMd

            Ui.NotificationAppIcon {
                notification: card.notification
                count: card.groupCount
            }

            Column {
                width: parent.width - 40 - parent.spacing
                spacing: 2

                Item {
                    width: parent.width
                    height: 22

                    Ui.ThemeText {
                        anchors.left: parent.left
                        anchors.right: controls.visible ? controls.left : parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: [card.notification.app_name || "", Ui.NotificationPresentation.timeLabel(card.notification.created_unix_ms, card.nowMs)].filter(function (part) {
                            return part.length > 0;
                        }).join(" · ")
                        color: card.urgency >= 2 ? Ui.Theme.danger : Ui.Theme.mutedText
                        elide: Text.ElideRight
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }

                    Row {
                        id: controls
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        visible: opacity > 0
                        opacity: card.controlsRevealed ? 1 : 0

                        Behavior on opacity {
                            enabled: !Ui.Theme.noAnimations
                            NumberAnimation {
                                duration: Ui.Theme.animationFast
                            }
                        }

                        Ui.FlatIconButton {
                            visible: card.breakoutVisible
                            width: 26
                            height: 26
                            icon: "󰅂"
                            accessibleName: "Show all " + card.groupCount + " in notification center"
                            toolTip: accessibleName
                            onClicked: card.breakoutRequested()
                        }
                        Ui.FlatIconButton {
                            visible: card.replyAction !== null && !card.replyVisible
                            width: 26
                            height: 26
                            icon: "󰑚"
                            accessibleName: "Reply"
                            toolTip: accessibleName
                            onClicked: card.replyOpen = true
                        }
                        Ui.FlatIconButton {
                            width: 26
                            height: 26
                            icon: "󰒲"
                            accessibleName: "Snooze for 15 minutes"
                            toolTip: accessibleName
                            onClicked: card.controller.snoozeNotification(card.notification.id, 15)
                        }
                        Ui.FlatIconButton {
                            width: 26
                            height: 26
                            icon: "󰅖"
                            accessibleName: "Dismiss"
                            toolTip: accessibleName
                            onClicked: card.removing = true
                        }
                    }
                }

                Ui.ThemeText {
                    width: parent.width
                    text: card.notification.summary || card.notification.app_name || "Notification"
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }

                Ui.ThemeText {
                    width: parent.width
                    visible: text.length > 0
                    text: card.notification.body || ""
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    color: Ui.Theme.mix(Ui.Theme.text, Ui.Theme.mutedText, 0.35)
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }
        }

        Ui.NotificationActionList {
            width: parent.width
            actions: card.actions
            controlHeight: 32
            onTriggered: function (actionKey) {
                card.controller.invokeNotificationAction(card.notification.id, actionKey);
            }
        }

        Ui.NotificationReplyRow {
            id: replyRow
            visible: card.replyVisible
            notificationId: Number(card.notification.id)
            draftText: card.draft
            sending: card.replyStatus.pending === true
            errorText: card.replyStatus.error || ""
            onDraftEdited: function (text) {
                if (card.replyState)
                    card.replyState.setDraft(notificationId, text);
            }
            submitReply: function (id, text) {
                return card.controller.replyNotification(id, text);
            }
        }
    }

    // Remaining display time. The daemon owns expiry; this only reflects it.
    Rectangle {
        id: expiry
        readonly property double expiresMs: Number(card.notification.expires_unix_ms || 0)
        readonly property double totalMs: expiresMs - Number(card.notification.updated_unix_ms || card.notification.created_unix_ms || 0)
        readonly property bool timed: expiresMs > 0 && totalMs > 0
        property real fraction: 1
        visible: timed
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: card.radius
        anchors.bottomMargin: 1
        width: (card.width - card.radius * 2) * fraction
        height: 2
        radius: 1
        color: Ui.Theme.withAlpha(card.urgency >= 2 ? Ui.Theme.danger : Ui.Theme.accent, 0.55)

        function restart(): void {
            countdown.stop();
            if (!timed)
                return;
            const remaining = Math.max(0, expiresMs - Date.now());
            fraction = Math.min(1, remaining / totalMs);
            countdown.duration = remaining;
            countdown.start();
        }
        onExpiresMsChanged: restart()
        Component.onCompleted: restart()

        NumberAnimation {
            id: countdown
            target: expiry
            property: "fraction"
            to: 0
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: card.visible
        onTriggered: card.nowMs = Date.now()
    }

    onReplyOpenChanged: if (replyOpen)
        Qt.callLater(replyRow.focusInput)

    Ui.RemovalAnimation {
        targetItem: card
        removalRequested: card.removing
        finishRemoval: function () {
            card.controller.dismissNotification(card.notification.id);
        }
    }
}
