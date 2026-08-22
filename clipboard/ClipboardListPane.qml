pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property ClipboardController controller
    chooserController: controller
    resultModel: controller.filteredResultsModel
    emptyText: controller.refreshInFlight ? "Loading clipboard history…" : "Clipboard history is empty"
    placeholder: "Search clipboard…"
    icon: "󰅇"
    powered: true
    refreshing: false
    busy: controller.refreshInFlight
    powerEnabled: false
    refreshEnabled: !controller.actionInFlight && !controller.wipeChallenge
    refreshIcon: "󰆴"
    refreshHandler: function () { pane.controller.requestWipe(); }
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight
    filterText: controller.filterText
    status: controller.status
    bodySpacing: Math.round(Ui.Theme.spacingMd * densityScale)
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        ClipboardListRow { listPane: pane; controller: pane.controller }
    }
}
