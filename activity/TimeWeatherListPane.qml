pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property TimeWeatherController controller
    chooserController: controller
    resultModel: controller.cityModel
    emptyIcon: "cloud"
    emptyState: controller.snapshotReadError ? "unavailable" : controller.backend.snapshotLoading || controller.activity.syncing ? "loading" : !controller.snapshotLoaded && !controller.activity.available && !controller.timezone.available ? "unavailable" : controller.filterText.trim() && controller.cities.length > 0 ? "filtered" : "empty"
    emptyText: controller.snapshotReadError || (emptyState === "loading" ? qsTr("Loading cities…") : emptyState === "unavailable" ? qsTr("City information unavailable") : emptyState === "filtered" ? qsTr("No matching cities") : qsTr("No configured cities"))
    placeholder: "Search cities or timezones…"
    icon: "󰅐"
    powered: true
    refreshing: controller.activity.syncing
    busy: controller.activity.syncing || controller.screenshotInFlight
    powerEnabled: false
    refreshEnabled: !controller.activity.syncing && !controller.screenshotInFlight
    filterText: controller.filterText
    status: controller.screenshotStatus.length > 0 ? controller.screenshotStatus : (controller.activity.syncing ? "Updating time and weather…" : controller.cities.length + (controller.cities.length === 1 ? " city" : " cities"))

    rowDelegate: Component {
        TimeWeatherListRow {
            listPane: pane
            nowMs: pane.controller.currentTimeMs
        }
    }
}
