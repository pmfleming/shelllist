pragma ComponentBehavior: Bound

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
    readonly property int urgency: Ui.NotificationPresentation.urgency(notification)
    readonly property var actions: Ui.NotificationPresentation.standardActions(notification)
    readonly property var replyAction: Ui.NotificationPresentation.replyAction(notification)
    readonly property var defaultAction: active ? Ui.NotificationPresentation.defaultAction(notification) : null
    readonly property bool replyVisible: replyOpen || draft.length > 0 || replyStatus.pending === true || String(replyStatus.error || "").length > 0
    readonly property bool controlsRevealed: hover.hovered || replyVisible || hoverControls.activeFocusInside

    signal groupToggled

    objectName: "notificationHistoryRow-" + notification.id
    width: ListView.view ? ListView.view.width : 300
    implicitHeight: historyContent.implicitHeight + Ui.Theme.spacingMd * 2
    radius: Ui.Theme.cardRadius
    color: urgency >= 2 && active ? Ui.Theme.mix(Ui.Theme.surfaceRaised, Ui.Theme.danger, 0.08) : active ? Ui.Theme.surfaceRaised : Ui.Theme.mix(Ui.Theme.surfaceRaised, Ui.Theme.surface, 0.5)
    border.color: urgency >= 2 && active ? Ui.Theme.withAlpha(Ui.Theme.danger, 0.6) : active ? Ui.Theme.withAlpha(Ui.Theme.accent, 0.36) : Ui.Theme.border

    HoverHandler {
        id: hover
    }

    // Beneath the content: clicking the card activates the notification's default action.
    MouseArea {
        anchors.fill: parent
        enabled: row.defaultAction !== null
        cursorShape: Qt.PointingHandCursor
        onClicked: row.notificationState.invokeNotificationAction(row.notification.id, row.defaultAction.key)
    }

    Row {
        id: historyContent
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: Ui.Theme.spacingMd
        }
        spacing: Ui.Theme.spacingMd

        Ui.NotificationAppIcon {
            id: iconSlot
            visible: !row.groupedContext
            width: visible ? 36 : 0
            height: 36
            notification: row.notification
            count: row.groupToggleVisible ? row.groupCount : 1
        }

        Column {
            width: parent.width - iconSlot.width - (iconSlot.visible ? parent.spacing : 0)
            spacing: 2

            Item {
                width: parent.width
                height: 22

                Row {
                    anchors.left: parent.left
                    anchors.right: controls.visible ? controls.left : parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Ui.Theme.spacingXs

                    Rectangle {
                        objectName: "notificationActiveDot"
                        visible: row.active
                        anchors.verticalCenter: parent.verticalCenter
                        width: 6
                        height: 6
                        radius: 3
                        color: row.urgency >= 2 ? Ui.Theme.danger : Ui.Theme.accent
                    }
                    Ui.ThemeText {
                        width: parent.width - (row.active ? 6 + parent.spacing : 0)
                        text: [row.groupedContext ? "" : row.notification.app_name || "", Ui.NotificationPresentation.timeLabel(row.notification.created_unix_ms, row.controller.nowMs)].filter(function (part) {
                            return part.length > 0;
                        }).join(" · ")
                        color: row.urgency >= 2 && row.active ? Ui.Theme.danger : Ui.Theme.mutedText
                        elide: Text.ElideRight
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }

                Row {
                    id: controls
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    // Hidden by opacity only, so keyboard focus can still reach them.
                    Row {
                        id: hoverControls
                        readonly property bool activeFocusInside: replyButton.activeFocus || snoozeButton.activeFocus || dismissButton.activeFocus
                        spacing: 2
                        visible: row.active
                        opacity: row.controlsRevealed ? 1 : 0

                        Behavior on opacity {
                            enabled: !Ui.Theme.noAnimations
                            NumberAnimation {
                                duration: Ui.Theme.animationFast
                            }
                        }

                        Ui.FlatIconButton {
                            id: replyButton
                            visible: row.replyAction !== null && !row.replyVisible
                            width: 26
                            height: 26
                            icon: "󰑚"
                            accessibleName: "Reply"
                            toolTip: accessibleName
                            onClicked: row.replyOpen = true
                        }
                        Ui.FlatIconButton {
                            id: snoozeButton
                            width: 26
                            height: 26
                            icon: "󰒲"
                            accessibleName: "Snooze for 15 minutes"
                            toolTip: accessibleName
                            onClicked: row.notificationState.snoozeNotification(row.notification.id, 15)
                        }
                        Ui.FlatIconButton {
                            id: dismissButton
                            width: 26
                            height: 26
                            icon: "󰅖"
                            accessibleName: "Dismiss"
                            toolTip: accessibleName
                            onClicked: row.notificationState.dismissNotification(row.notification.id)
                        }
                    }
                    Ui.FlatIconButton {
                        id: expandButton
                        visible: row.groupToggleVisible
                        width: 26
                        height: 26
                        icon: "󰅀"
                        accessibleName: "Expand " + row.groupCount + " notifications"
                        toolTip: accessibleName
                        onClicked: row.groupToggled()
                    }
                }
            }

            Ui.ThemeText {
                width: parent.width
                text: row.notification.summary || row.notification.app_name || "Notification"
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.weight: Ui.Theme.fontWeightDemiBold
            }

            Ui.ThemeText {
                id: bodyText
                objectName: "notificationBody"
                readonly property bool expandable: truncated || row.bodyExpanded
                width: parent.width
                visible: text.length > 0
                text: row.notification.body || ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: row.bodyExpanded ? 2147483647 : 3
                elide: Text.ElideRight
                color: bodyToggle.containsMouse ? Ui.Theme.text : Ui.Theme.mix(Ui.Theme.text, Ui.Theme.mutedText, 0.35)
                font.pixelSize: Ui.Theme.fontSizeSmall
                Accessible.role: expandable ? Accessible.Button : Accessible.StaticText
                Accessible.name: expandable ? (row.bodyExpanded ? "Show less" : "Show more") : text
                Accessible.onPressAction: if (expandable)
                    row.bodyExpanded = !row.bodyExpanded

                // Long bodies expand in place; the elision marks that there is more.
                MouseArea {
                    id: bodyToggle
                    anchors.fill: parent
                    enabled: bodyText.expandable
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.bodyExpanded = !row.bodyExpanded
                }
            }

            Item {
                width: parent.width
                height: Ui.Theme.spacingXs
                visible: actionList.visible || replyRow.visible
            }

            Ui.NotificationActionList {
                id: actionList
                width: parent.width
                visible: row.active && row.actions.length > 0
                actions: row.actions
                minimumButtonWidth: 68
                maximumButtonWidth: 130
                characterWidth: 7
                horizontalPadding: 22
                controlHeight: 30
                onTriggered: function (actionKey) {
                    row.notificationState.invokeNotificationAction(row.notification.id, actionKey);
                }
            }

            Ui.NotificationReplyRow {
                id: replyRow
                visible: row.replyVisible
                notificationId: Number(row.notification.id)
                draftText: row.draft
                sending: row.replyStatus.pending === true
                canReply: row.active && row.replyAction !== null
                errorText: row.replyStatus.error || ""
                onDraftEdited: function (text) {
                    row.notificationState.setDraft(notificationId, text);
                }
                submitReply: function (id, text) {
                    return row.notificationState.replyNotification(id, text);
                }
            }
        }
    }

    onReplyOpenChanged: if (replyOpen)
        Qt.callLater(replyRow.focusInput)
}
