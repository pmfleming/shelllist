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
    busy: controller.refreshInFlight || controller.actionInFlight
        || controller.screenshotInFlight || controller.settingsInFlight
    powerEnabled: false
    refreshEnabled: !controller.actionInFlight && !controller.screenshotInFlight
        && !controller.settingsInFlight
    refreshHandler: function () { controller.refresh(true); }
    iconActionEnabled: !controller.actionInFlight && !controller.screenshotInFlight
        && !controller.settingsInFlight
    filterText: controller.filterText
    status: controller.status
    focusOnCompleted: true
    toolbarHeight: Math.max(34, Math.round(Ui.Theme.compactControlHeight * uiScale))
    toolbarComponent: Component {
        ApplicationCategoryTabs { controller: pane.controller }
    }
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        ApplicationListRow { listPane: pane }
    }
}
