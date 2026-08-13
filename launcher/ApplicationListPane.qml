pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property ApplicationController controller
    required property real uiScale
    chooserController: controller
    densityScale: uiScale
    resultModel: controller.filteredResultsModel
    emptyText: controller.refreshInFlight ? "Loading applications…" : "No matching applications"
    placeholder: "Search applications…"
    icon: "󰀻"
    powered: true
    refreshing: controller.refreshInFlight
    busy: controller.refreshInFlight || controller.actionInFlight || controller.screenshotInFlight
    powerEnabled: false
    refreshEnabled: !controller.actionInFlight && !controller.screenshotInFlight
    iconActionEnabled: !controller.actionInFlight && !controller.screenshotInFlight
    filterText: controller.filterText
    status: controller.status
    focusOnCompleted: true
    onIconClicked: controller.screenshotRequested()
    onRefreshRequested: controller.refresh(true)

    rowDelegate: Component {
        ApplicationListRow { listPane: pane }
    }
}
