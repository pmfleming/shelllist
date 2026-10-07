pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "ApplicationPreferences.js" as Preferences
import "ApplicationPresentation.js" as Presentation

Ui.ChooserListPane {
    id: pane

    required property ApplicationController controller
    readonly property var categoryFilters: Presentation.categoryFilterOptions(Preferences.categories)
    readonly property var activeCategoryFilter: Presentation.categoryFilterOption(categoryFilters, controller.categoryFilter)
    readonly property var nextCategoryFilter: Presentation.nextCategoryFilterOption(categoryFilters, controller.categoryFilter)

    chooserController: controller
    resultModel: controller.filteredResultsModel
    emptyIcon: "apps"
    emptyState: controller.catalogError ? "unavailable" : controller.refreshInFlight ? "loading" : controller.catalogRevision < 0 ? "unavailable" : controller.filterText.trim() || controller.categoryFilter ? "filtered" : "empty"
    emptyText: controller.catalogError || (emptyState === "loading" ? qsTr("Loading applications…") : emptyState === "unavailable" ? qsTr("Application catalog unavailable") : emptyState === "filtered" ? qsTr("No matching applications") : qsTr("No applications found"))
    placeholder: "Search applications…"
    icon: "󰀻"
    powered: true
    refreshing: controller.refreshInFlight
    busy: controller.refreshInFlight || controller.operationBlocked
    powerEnabled: false
    powerVisible: false
    refreshEnabled: !controller.operationBlocked
    function requestRefresh(): void {
        controller.refresh(true);
    }
    searchActionIcon: activeCategoryFilter.icon
    searchActionToolTip: "Category: " + activeCategoryFilter.label + " · Click for " + nextCategoryFilter.label
    searchActionEnabled: !controller.operationBlocked
    filterText: controller.filterText
    status: controller.selectedActionMessage || controller.status
    onSearchActionRequested: controller.selectCategory(nextCategoryFilter.value)

    rowDelegate: Component {
        ApplicationListRow {
            listPane: pane
        }
    }
}
