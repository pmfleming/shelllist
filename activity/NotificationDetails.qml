pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: pane
    required property NotificationController controller
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
            sourceComponent: pane.controller.detailsTab === "controls" ? controls : index
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
}
