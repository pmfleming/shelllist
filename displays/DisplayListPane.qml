pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane
    required property DisplayController controller
    objectName: "displayList"
    chooserController: controller
    resultModel: controller.filteredResultsModel
    filterText: controller.filterText
    placeholder: qsTr("Search displays…")
    emptyIcon: "monitor"
    emptyState: controller.displayPolicyError || controller.displayPolicyState.error ? "unavailable" : controller.backend.snapshotLoading ? "loading" : !controller.stateReady ? "unavailable" : !controller.displayPolicyState.available ? "disabled" : controller.outputs.length > 0 ? "filtered" : "empty"
    emptyText: controller.displayPolicyError || controller.displayPolicyState.error || (emptyState === "loading" ? qsTr("Reading displays…") : emptyState === "unavailable" ? qsTr("Display service unavailable") : emptyState === "disabled" ? controller.statusMessage : emptyState === "filtered" ? qsTr("No matching displays") : qsTr("No connected displays"))
    icon: "󰍹"
    powered: controller.activeCount > 0
    powerVisible: false
    busy: controller.actionInFlight
    enabled: !controller.discardPrompt && !controller.actionInFlight && !controller.trial
    refreshEnabled: !controller.actionInFlight && !controller.trial
    status: controller.statusMessage || qsTr("%1 active · %2 connected").arg(controller.activeCount).arg(controller.outputs.length)
    iconActionEnabled: controller.activeCount > 0
    iconAccessibleName: qsTr("Identify all enabled displays")
    onIconClicked: controller.identify()
    searchActionIcon: "settings"
    searchActionToolTip: qsTr("Display settings")
    searchActionEnabled: !controller.navigationBlocked
    onSearchActionRequested: controller.openGlobalSettings()
    rowDelegate: Component {
        DisplayListRow {
            listPane: pane
        }
    }
}
