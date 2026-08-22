pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property ApplicationController controller
    chooserController: controller
    resultModel: controller.filteredResultsModel
    emptyText: controller.refreshInFlight ? "Loading applications…" : "No matching applications"
    placeholder: "Search applications…"
    icon: "󰀻"
    powered: true
    refreshing: controller.refreshInFlight
    busy: controller.refreshInFlight || controller.operationBlocked
    powerEnabled: false
    refreshEnabled: !controller.operationBlocked
    refreshHandler: function () { controller.refresh(true); }
    iconActionEnabled: !controller.operationBlocked
    filterText: controller.filterText
    status: controller.status
    focusOnCompleted: true
    toolbarHeight: Math.max(34, Math.round(Ui.Theme.compactControlHeight * densityScale))
    toolbarComponent: Component {
        ApplicationCategoryTabs { controller: pane.controller }
    }
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        ApplicationListRow { listPane: pane }
    }
}
