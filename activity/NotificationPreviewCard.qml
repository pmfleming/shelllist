pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// A passive projection plus command intents. Timeline state, deletion consent
// and backend ownership remain in the containing page/controller.
Ui.DetailColumnCard {
    id: card
    required property var entry
    required property double nowMs
    property bool deleteEnabled: false
    signal expansionRequested
    signal deleteRequested(var record)

    objectName: "notificationPreview-" + entry.key
    color: Ui.Theme.surfaceContainer
    Ui.ThemeText {
        objectName: "notificationPreviewTitle-" + card.entry.key
        Layout.fillWidth: true
        text: Ui.NotificationPresentation.previewHeading(card.entry.preview)
        visible: text.length > 0
        textFormat: Text.PlainText
        elide: Text.ElideRight; maximumLineCount: 1
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Ui.ThemeText {
        objectName: "notificationPreviewBody-" + card.entry.key
        Layout.fillWidth: true
        text: Ui.NotificationPresentation.previewBody(card.entry.preview)
        visible: text.length > 0
        textFormat: Text.PlainText
        wrapMode: Text.Wrap; elide: Text.ElideRight; maximumLineCount: 2
    }
    Ui.ThemeText {
        objectName: "notificationPreviewMeta-" + card.entry.key
        Layout.fillWidth: true
        text: Ui.NotificationPresentation.timeLabel(card.entry.preview.created_unix_ms, card.nowMs) + (card.entry.stack ? qsTranslate("NotificationIndex", " · %1 similar notifications").arg(card.entry.count) : "")
        color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.metadataSize
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Item { Layout.fillWidth: true }
        Ui.FlatIconButton {
            objectName: "notificationCard-" + card.entry.key + ":expand"
            visible: card.entry.stack
            sizeRole: "secondary"
            uiScale: Ui.Theme.expandedSecondaryActionScale
            icon: card.entry.expanded ? "expand_less" : "expand_more"
            accessibleName: card.entry.expanded ? qsTranslate("NotificationIndex", "Collapse similar notifications") : qsTranslate("NotificationIndex", "Expand similar notifications")
            onClicked: card.expansionRequested()
        }
        Ui.FlatIconButton {
            objectName: "notificationCard-" + card.entry.key + ":delete"
            visible: !card.entry.stack
            sizeRole: "secondary"
            uiScale: Ui.Theme.expandedSecondaryActionScale
            icon: "delete"
            accessibleName: qsTranslate("NotificationIndex", "Delete this notification")
            enabled: card.deleteEnabled
            onClicked: card.deleteRequested(card.entry.preview)
        }
    }
}
