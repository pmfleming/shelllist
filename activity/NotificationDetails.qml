pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: pane
    required property NotificationController controller
    required property Ui.DetailsNavigation navigation
    Loader {
        anchors.fill: parent
        anchors.leftMargin: Ui.Theme.spacingMd
        anchors.rightMargin: Ui.Theme.spacingMd
        active: pane.controller.detailsOpen && pane.controller.settingsOpen
        sourceComponent: Ui.DetailFlickable {
            viewMemory: pane.controller.viewMemory
            memoryTab: "settings"
            NotificationSettings { notificationState: pane.controller.notificationState }
        }
    }
    Ui.TabbedDetailsStack {
        anchors.fill: parent
        visible: !pane.controller.settingsOpen
        enabled: pane.controller.detailsOpen
        footerHeight: Ui.Theme.controlHeight
        selectedValue: pane.controller.detailsTab
        tabs: pane.controller.tabs
        onSelected: function (value) { pane.controller.setDetailsTab(value); }
        Loader {
            anchors.fill: parent
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.rightMargin: Ui.Theme.spacingMd
            active: pane.controller.detailsOpen && !pane.controller.settingsOpen
            sourceComponent: pane.controller.detailsTab === "message" ? message : pane.controller.detailsTab === "controls" ? controls : index
        }
    }
    Component {
        id: index
        NotificationIndex {
            controller: pane.controller
        }
    }
    Component {
        id: controls
        NotificationAppSettings { controller: pane.controller }
    }
    Component {
        id: message
        Ui.DetailFlickable {
            viewMemory: pane.controller.viewMemory
            memoryTab: "message::" + pane.controller.selectedKey
            Ui.ThemeText {
                width: parent.width
                visible: pane.controller.catalog.detailError.length > 0
                text: pane.controller.catalog.detailError
                textFormat: Text.PlainText
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
            }
            Ui.ContentState {
                width: parent.width
                visible: !pane.controller.selectedRecord
                icon: "notifications_none"
                kind: pane.controller.catalog.detailBusy ? "loading" : "unavailable"
                text: pane.controller.catalog.detailBusy ? qsTr("Loading notification…") : qsTr("This notification is no longer available")
            }
            NotificationHistoryRow {
                width: parent.width
                visible: !!pane.controller.selectedRecord
                controller: pane.controller
                navigation: pane.navigation
                record: pane.controller.selectedRecord || ({})
            }
        }
    }
}
