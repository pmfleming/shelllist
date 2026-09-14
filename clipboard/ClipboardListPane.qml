pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property ClipboardController controller
    chooserController: controller
    resultModel: controller.filteredResultsModel
    emptyText: controller.refreshInFlight ? "Loading clipboard history…" : "Clipboard history is empty"
    placeholder: controller.multiSelectMode ? controller.multiSelectedCount + " selected" : "Search clipboard…"
    icon: "󰅇"
    powered: true
    refreshing: false
    busy: controller.refreshInFlight
    powerEnabled: false
    refreshEnabled: !controller.actionInFlight && !controller.wipeChallenge && (!controller.multiSelectMode || controller.multiSelectedCount > 0)
    refreshIcon: "󰆴"
    refreshHandler: function () {
        if (pane.controller.multiSelectMode)
            pane.controller.requestBulkDelete();
        else
            pane.controller.openDeleteMenu();
    }
    iconActionEnabled: !controller.multiSelectMode && !controller.screenshotInFlight && !controller.actionInFlight
    searchActionIcon: controller.multiSelectMode ? "󰒆" : ""
    searchActionToolTip: "Select all visible entries"
    searchActionEnabled: controller.multiSelectMode && !controller.allVisibleSelected
    filterText: controller.filterText
    status: controller.multiSelectMode ? controller.multiSelectedCount + " selected · Esc to finish" : controller.status
    onSearchActionRequested: controller.selectAllVisible()
    bodySpacing: Math.round(Ui.Theme.spacingMd * densityScale)
    onIconClicked: controller.screenshotRequested()

    listOptionsComponent: Component {
        Ui.ActionToolbar {
            implicitHeight: pane.controller.historyCursor.length > 0 ? Ui.Theme.controlHeight : 0
            visible: implicitHeight > 0
            actions: [{ id: "more", label: "Load more entries", enabled: !pane.controller.refreshInFlight }]
            onTriggered: pane.controller.loadMoreHistory()
        }
    }

    rowDelegate: Component {
        ClipboardListRow {
            listPane: pane
            controller: pane.controller
        }
    }
}
