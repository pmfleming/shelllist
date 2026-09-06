pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: row

    required property var record
    required property NotificationController controller
    readonly property NotificationState notificationState: controller.notificationState
    property bool bodyExpanded: false
    property bool replyOpen: false
    readonly property var replyStatus: notificationState.replies[notification.id] || ({})
    readonly property string draft: String(notificationState.drafts[notification.id] || "")
    property int groupCount: 1
    property bool groupedContext: false
    property bool groupToggleVisible: false
    readonly property var notification: Ui.NotificationPresentation.notificationFor(record)
    readonly property bool active: notificationState.isActive(notification.id)
    readonly property var actions: Array.isArray(notification.actions)
        ? notification.actions.filter(function (action) { return !row.isReplyAction(action); }) : []
    readonly property var replyAction: Array.isArray(notification.actions)
        ? notification.actions.find(function (action) { return row.isReplyAction(action); }) || null
        : null

    signal groupToggled

    FontMetrics {
        id: actionFont
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }

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

    objectName: "notificationHistoryRow-" + notification.id
    width: ListView.view ? ListView.view.width : 300
    implicitHeight: Math.max(78, historyContent.implicitHeight + Ui.Theme.spacingMd * 2)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surfaceRaised
    border.color: active ? Ui.Theme.withAlpha(Ui.Theme.accent, 0.48) : Ui.Theme.border

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

            Item {
                id: iconSlot
                visible: !row.groupedContext
                width: visible ? 32 : 0
                height: 32

                Image {
                    anchors.fill: parent
                    source: row.iconSource()
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }

                Rectangle {
                    visible: row.groupToggleVisible && row.groupCount > 1
                    width: 18
                    height: 18
                    radius: 9
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    color: Ui.Theme.accent
                    border.color: Ui.Theme.surfaceRaised
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: row.groupCount > 9 ? "9+" : String(row.groupCount)
                        color: Ui.Theme.accentText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 9
                        font.weight: Ui.Theme.fontWeightBold
                    }
                }
            }

            Column {
                id: titleColumn
                width: parent.width - iconSlot.width - expandButton.width
                    - snoozeButton.width - dismissButton.width
                    - parent.spacing * ((iconSlot.visible ? 1 : 0)
                        + (expandButton.visible ? 1 : 0)
                        + (snoozeButton.visible ? 1 : 0)
                        + (dismissButton.visible ? 1 : 0))
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
                    text: (row.groupedContext ? "" : (row.notification.app_name || "") + "  ")
                        + Qt.formatDateTime(new Date(Number(
                            row.notification.created_unix_ms || 0)), "d MMM HH:mm")
                        + (row.active ? "" : " · History")
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }

            Ui.FlatIconButton {
                id: expandButton
                visible: row.groupToggleVisible
                width: visible ? 28 : 0
                height: 28
                icon: "󰅂"
                accessibleName: "Expand notification stack"
                toolTip: accessibleName
                onClicked: row.groupToggled()
            }
            Ui.FlatIconButton {
                id: snoozeButton
                visible: row.active
                width: visible ? 28 : 0
                height: 28
                icon: "󰒲"
                accessibleName: "Snooze notification for 15 minutes"
                toolTip: accessibleName
                onClicked: row.notificationState.snoozeNotification(row.notification.id, 15)
            }
            Ui.FlatIconButton {
                id: dismissButton
                visible: row.active
                width: visible ? 28 : 0
                height: 28
                icon: "󰅖"
                accessibleName: "Dismiss notification"
                toolTip: accessibleName
                onClicked: row.notificationState.dismissNotification(row.notification.id)
            }
        }

        Text {
            id: bodyText
            width: parent.width
            visible: text.length > 0
            text: row.notification.body || ""
            textFormat: Text.PlainText
            color: Ui.Theme.text
            wrapMode: Text.Wrap
            maximumLineCount: row.bodyExpanded ? 2147483647 : 3
            elide: Text.ElideRight
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
        }

        ActivityHeaderButton {
            visible: bodyText.truncated || row.bodyExpanded
            label: row.bodyExpanded ? "Show less" : "Show more"
            onTriggered: row.bodyExpanded = !row.bodyExpanded
        }

        Flow {
            id: actionsFlow
            width: parent.width
            visible: row.active && row.actions.length > 0
            spacing: Ui.Theme.spacingSm
            Repeater {
                model: row.actions
                Ui.ActionButton {
                    required property var modelData
                    width: Math.min(actionsFlow.width, Math.max(68, Math.min(130,
                        String(modelData.label || "Action").length * 7 + 22)))
                    height: 32
                    label: actionFont.elidedText(String(modelData.label || "Action"),
                        Qt.ElideRight, width - 20)
                    accessibleName: modelData.label || "Action"
                    toolTip: accessibleName
                    onClicked: row.notificationState.invokeNotificationAction(
                        row.notification.id, modelData.key)
                }
            }
        }

        ActivityHeaderButton {
            visible: row.active && row.replyAction !== null && !replyRow.visible
            label: "Reply"
            onTriggered: row.replyOpen = true
        }
        Ui.NotificationReplyRow {
            id: replyRow
            visible: row.replyOpen || row.draft.length > 0 || row.replyStatus.pending === true
                || String(row.replyStatus.error || "").length > 0
            notificationId: Number(row.notification.id)
            draftText: row.draft
            sending: row.replyStatus.pending === true
            canReply: row.active && row.replyAction !== null
            errorText: row.replyStatus.error || ""
            onDraftEdited: function (text) { row.notificationState.setDraft(notificationId, text); }
            submitReply: function (id, text) {
                return row.notificationState.replyNotification(id, text);
            }
        }
    }
}
