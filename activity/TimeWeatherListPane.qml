pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property TimeWeatherController controller
    chooserController: controller
    resultModel: controller.cityModel
    emptyText: controller.activity.syncing ? "Loading cities…" : "No configured cities"
    placeholder: "Search cities or timezones…"
    icon: "󰅐"
    powered: true
    refreshing: controller.activity.syncing
    busy: controller.activity.syncing || controller.screenshotInFlight
    powerEnabled: false
    refreshEnabled: !controller.activity.syncing && !controller.screenshotInFlight
    iconActionEnabled: !controller.screenshotInFlight
    filterText: controller.filterText
    status: controller.screenshotStatus.length > 0 ? controller.screenshotStatus : (controller.activity.syncing ? "Updating time and weather…" : controller.cities.length + (controller.cities.length === 1 ? " city" : " cities"))
    listInset: Math.round(12 * densityScale)
    focusOnCompleted: true
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        TimeWeatherListRow {
            listPane: pane
            nowMs: pane.controller.currentTimeMs
        }
    }
}
