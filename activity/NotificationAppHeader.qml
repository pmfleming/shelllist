import QtQuick
import Shelllist.Ui as Ui

Ui.DetailsHeader {
    id: header
    required property NotificationController controller
    uiScale: 1
    compactSecondaryActions: true
    icon: Ui.NotificationIconSource.fallback(controller.selectedApp?.latest)
    iconSource: Ui.NotificationIconSource.resolve(controller.selectedApp?.latest)
    title: controller.selectedApp?.latest.app_name || qsTr("Notifications")
    subtitle: qsTr("%1 notifications").arg(controller.selectedApp?.total_count || 0) + (controller.appPolicy.silent ? qsTr(" · Silent") : "")
    actions: controller.appCommands
    onActionTriggered: function (id) { header.controller.triggerAppAction(id, header.controller.selectedAppKey); }
}
