pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Activity as Activity

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
    readonly property Activity.NotificationState replyState: controller.notificationState
    readonly property string recordKey: Ui.NotificationPresentation.recordKey(notification)
    readonly property var replyStatus: replyState ? replyState.replies[recordKey] || ({}) : ({})
    readonly property string draft: replyState ? String(replyState.drafts[recordKey] || "") : ""
    property bool replyOpen: false
    readonly property bool replyVisible: replyAction !== null && (replyOpen || draft.length > 0 || replyStatus.pending === true || String(replyStatus.error || "").length > 0)
    Accessible.role: Accessible.Button
    Accessible.name: notification.summary || notification.app_name || qsTr("Notification")
    Accessible.onPressAction: if (!removing) activate()
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

    Ui.InteractiveBehavior on x {
        animate: !swipe.drag.active
        duration: Ui.Theme.animationNormal
    }

    Ui.Elevation {
        anchors.fill: parent
        radius: card.radius
        level: 3
        z: -1
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

        Ui.DetailsHeader {
            width: parent.width
            uiScale: 1
            titlePixelSize: Ui.Theme.fontSizeLabel
            title: card.notification.summary || card.notification.app_name || qsTr("Notification")
            subtitle: [card.notification.app_name, Ui.NotificationPresentation.timeLabel(card.notification.created_unix_ms, card.nowMs)].filter(Boolean).join(" · ")
            subtitleColor: card.urgency >= 2 ? Ui.Theme.danger : Ui.Theme.mutedText
            icon: "notifications"
            iconSource: Ui.NotificationIconSource.resolve(card.notification)
            iconCount: card.groupCount
            tabFocusEnabled: true
            enabled: !card.removing
            actions: [
                {id: "open", label: qsTr("Open notification"), icon: "open_in_new", visible: card.defaultAction !== null, presentation: {group: "primary"}},
                {id: "breakout", label: qsTr("Show all %1 in notification center").arg(card.groupCount), icon: "unfold_more", visible: card.breakoutVisible, presentation: {group: "toolbar"}},
                {id: "reply", label: qsTr("Reply"), icon: "reply", visible: card.replyAction !== null && !card.replyVisible, presentation: {group: "toolbar"}},
                {id: "snooze", label: qsTr("Snooze for 15 minutes"), icon: "snooze", presentation: {group: "toolbar"}},
                {id: "dismiss", label: qsTr("Dismiss"), icon: "close", presentation: {group: "toolbar"}}
            ]
            onActionTriggered: function(actionId) {
                if (actionId === "open") card.activate();
                else if (actionId === "breakout") card.breakoutRequested();
                else if (actionId === "reply") card.replyOpen = true;
                else if (actionId === "snooze") card.controller.snoozeNotification(card.notification.id, 15);
                else if (actionId === "dismiss") card.removing = true;
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
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }

        Ui.NotificationActionList {
            width: parent.width
            actions: card.actions
            enabled: !card.removing
            onTriggered: function (actionKey) {
                card.controller.invokeNotificationAction(card.notification.id, actionKey);
            }
        }

        Ui.NotificationReplyRow {
            id: replyRow
            visible: card.replyVisible
            notificationKey: card.recordKey
            draftText: card.draft
            sending: card.replyStatus.pending === true
            errorText: card.replyStatus.error || ""
            onDraftEdited: function (text) {
                if (card.replyState)
                    card.replyState.setDraft(notificationKey, text);
            }
            onReplyRequested: function (key, text) {
                card.controller.replyNotification(key, text);
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
        onRemovalFinished: card.controller.dismissNotification(card.notification.id)
    }
}
