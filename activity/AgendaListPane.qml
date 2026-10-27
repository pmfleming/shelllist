pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane
    required property AgendaController controller
    chooserController: controller
    resultModel: controller.itemModel
    placeholder: qsTr("Search agenda…")
    icon: "󰒓"
    iconActionEnabled: true
    iconAccessibleName: qsTr("Agenda information")
    onIconClicked: controller.settingsOpen = true
    powered: true
    powerVisible: false
    powerEnabled: false
    refreshing: controller.loading
    busy: false
    refreshEnabled: !controller.modalOpen
    searchActionIcon: "add"
    searchActionToolTip: qsTr("Create item")
    searchActionEnabled: !controller.modalOpen && !controller.mutationBusy && AgendaRepository.ready
    onSearchActionRequested: controller.openCreation()
    filterText: controller.filterText
    status: controller.items.length + (controller.items.length === 1 ? qsTr(" item") : qsTr(" items"))
    emptyIcon: "calendar_month"
    emptyState: controller.loading ? "loading" : controller.error ? "unavailable" : controller.filterText ? "filtered" : "empty"
    emptyText: controller.loading ? qsTr("Loading agenda…") : controller.error || (controller.filterText ? qsTr("No matching items") : qsTr("No items"))
    preserveViewportOnAppend: true
    readonly property bool shouldLoad: listNearEnd && !!controller.nextCursor && !controller.loading && !controller.error
    onShouldLoadChanged: if (shouldLoad) Qt.callLater(controller.loadMore)
    rowDelegate: Component { AgendaListRow { listPane: pane } }
}
