pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page
    required property NotificationController controller
    required property bool overview
    readonly property var snapshot: controller.catalog.detail
    readonly property var entries: (overview ? snapshot.overview : snapshot.entries) || []
    viewMemory: controller.viewMemory
    memoryTab: overview ? "overview" : "notifications"
    Ui.NotificationAppIcon { id: identity; visible: false; notification: page.controller.selectedApp?.latest || ({}) }
    Ui.DetailsHeader {
        uiScale: 1
        width: parent.width
        icon: "notifications"
        iconSource: identity.source
        title: page.controller.selectedApp?.latest.app_name || qsTr("Notifications")
        subtitle: page.snapshot.count === undefined ? qsTr("Recent notifications") : page.controller.catalog.query ? qsTr("%1 matches of %2 recent notifications").arg(page.snapshot.count).arg(page.snapshot.total_count) : qsTr("%1 recent notifications").arg(page.snapshot.count)
        actions: page.overview ? [{id: "browse", label: qsTr("Browse notifications"), icon: "list", presentation: {group: "primary"}}] : []
        onActionTriggered: page.controller.setDetailsTab("notifications")
    }
    Ui.ThemeText {
        width: parent.width
        text: page.controller.catalog.detailError
        visible: text.length > 0
        color: Ui.Theme.danger
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    Ui.ContentState {
        width: parent.width
        visible: page.entries.length === 0
        icon: "notifications_none"
        kind: page.controller.catalog.detailError ? "unavailable" : page.controller.catalog.detailBusy ? "loading" : page.controller.catalog.query ? "filtered" : "empty"
        text: page.controller.catalog.detailError || (kind === "loading" ? qsTr("Loading notifications…") : kind === "filtered" ? qsTr("No matching notifications") : qsTr("No notifications"))
    }
    Ui.CommandGroup {
        objectName: "notificationIndexCommands"
        width: parent.width
        spacing: Ui.Theme.spacingSm
        Repeater {
            model: page.entries
            RowLayout {
                id: entry
                required property var modelData
                objectName: "notificationPreview-" + Ui.NotificationPresentation.recordKey(modelData)
                width: parent.width
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: Ui.Theme.spacingXs
                    Ui.ThemeText {
                        objectName: "notificationPreviewTitle-" + Ui.NotificationPresentation.recordKey(entry.modelData)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: Ui.NotificationPresentation.previewTitle(entry.modelData) || qsTr("Notification")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        wrapMode: Text.Wrap
                        maximumLineCount: page.overview ? 2 : 1
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        objectName: "notificationPreviewBody-" + Ui.NotificationPresentation.recordKey(entry.modelData)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: page.overview && text.length > 0
                        text: Ui.NotificationPresentation.previewBody(entry.modelData)
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                    }
                    Ui.ThemeText {
                        objectName: "notificationPreviewMeta-" + Ui.NotificationPresentation.recordKey(entry.modelData)
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: [Ui.NotificationPresentation.timeLabel(entry.modelData.created_unix_ms, page.controller.nowMs), entry.modelData.snoozed_until_unix_ms ? qsTr("Snoozed until %1").arg(new Date(entry.modelData.snoozed_until_unix_ms).toLocaleTimeString()) : entry.modelData.closed_unix_ms ? qsTr("Closed") : ""].filter(Boolean).join(" · ")
                        textFormat: Text.PlainText
                        color: Ui.Theme.mutedText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }
                Ui.ActionButton {
                    objectName: "notificationRead-" + Ui.NotificationPresentation.recordKey(entry.modelData)
                    sizeRole: "secondary"
                    icon: "article"
                    accessibleName: qsTr("Read %1 · %2").arg(Ui.NotificationPresentation.previewTitle(entry.modelData) || qsTr("Notification")).arg(new Date(entry.modelData.created_unix_ms).toLocaleString())
                    onClicked: page.controller.readRecord(entry.modelData)
                }
            }
        }
    }
    Ui.ThemeText {
        width: parent.width
        visible: page.overview && page.entries.length > 0
        text: qsTr("%1 of %2 shown").arg(page.entries.length).arg(page.snapshot.count || 0)
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.FormField {
        width: parent.width
        visible: !page.overview && (page.snapshot.pages || 1) > 1
        label: qsTr("Page")
        icon: "find_in_page"
        errorText: page.controller.catalog.pageError
        Ui.TextField {
            objectName: "notificationPage"
            Layout.fillWidth: true
            text: String(page.snapshot.page || 1)
            suffix: qsTr("of %1").arg(page.snapshot.pages || 1)
            Accessible.name: qsTr("Notification page, 1 to %1").arg(page.snapshot.pages || 1)
            inputMethodHints: Qt.ImhDigitsOnly
            onEdited: function (value) { page.controller.catalog.setPage(value); }
        }
    }
    Ui.SurfaceActionRow {
        width: parent.width
        visible: !page.overview && (page.snapshot.pages || 1) > 1
        headerCommands: false
        actions: [
            {id: "previous", label: qsTr("Previous notification page"), icon: "chevron_left", accessKey: "P", enabled: !page.controller.catalog.detailBusy && (page.snapshot.page || 1) > 1, presentation: {group: "toolbar"}},
            {id: "next", label: qsTr("Next notification page"), icon: "chevron_right", accessKey: "N", enabled: !page.controller.catalog.detailBusy && (page.snapshot.page || 1) < (page.snapshot.pages || 1), presentation: {group: "toolbar"}}
        ]
        onTriggered: function (actionId) { page.controller.catalog.setPage(String((page.snapshot.page || 1) + (actionId === "next" ? 1 : -1))); }
    }
    Ui.ThemeText {
        width: parent.width
        visible: page.controller.catalog.detailBusy && page.entries.length > 0
        text: qsTr("Loading…")
        color: Ui.Theme.mutedText
    }
}
