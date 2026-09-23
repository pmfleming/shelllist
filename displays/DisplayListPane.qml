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
    emptyText: !controller.stateReady ? qsTr("Connecting…") : controller.outputs.length === 0 ? qsTr("No connected displays") : qsTr("No matching displays")
    icon: "󰍹"
    powered: controller.activeCount > 0
    powerVisible: false
    busy: controller.actionInFlight
    enabled: !controller.navigationBlocked
    refreshEnabled: !controller.actionInFlight && !controller.trial
    focusOnCompleted: controller.uiActive
    status: controller.statusMessage || qsTr("%1 active · %2 connected").arg(controller.activeCount).arg(controller.outputs.length)
    iconActionEnabled: controller.activeCount > 0
    iconAccessibleName: qsTr("Identify all enabled displays")
    onIconClicked: controller.identify()
    rowDelegate: Component {
        DisplayListRow { listPane: pane }
    }
}
