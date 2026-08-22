pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences
import "ApplicationPresentation.js" as Presentation

Ui.ChooserListPane {
    id: pane

    required property ApplicationController controller
    readonly property var categoryFilters: Presentation.categoryFilterOptions(Preferences.categories)
    readonly property var activeCategoryFilter: Presentation.categoryFilterOption(
        categoryFilters, controller.categoryFilter)
    readonly property var nextCategoryFilter: Presentation.nextCategoryFilterOption(
        categoryFilters, controller.categoryFilter)

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
    searchActionIcon: activeCategoryFilter.icon
    searchActionToolTip: "Category: " + activeCategoryFilter.label
        + " · Click for " + nextCategoryFilter.label
    searchActionEnabled: !controller.operationBlocked
    filterText: controller.filterText
    status: controller.status
    focusOnCompleted: true
    onIconClicked: controller.screenshotRequested()
    onSearchActionRequested: controller.selectCategory(nextCategoryFilter.value)

    rowDelegate: Component {
        ApplicationListRow { listPane: pane }
    }
}
