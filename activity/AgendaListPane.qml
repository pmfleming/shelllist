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
    readonly property bool shouldLoad: listNearEnd && !!controller.nextCursor && !controller.cacheFull && !controller.loading && !controller.error && !controller.modalOpen
    onShouldLoadChanged: if (shouldLoad) Qt.callLater(controller.autoLoadMore)
    listFooterComponent: Component {
        Column {
            width: parent.width
            spacing: Ui.Theme.spacingMd
            Ui.ActionButton {
                objectName: "agendaFirstItems"
                label: qsTr("First items")
                icon: "arrow_upward"
                accessKey: "F"
                visible: pane.controller.windowOffset > 0 || !!pane.controller.error
                enabled: !pane.controller.loading && !pane.controller.modalOpen && !pane.controller.mutationBusy
                onClicked: pane.controller.showFirst()
            }
            Ui.ActionButton {
                objectName: "agendaMoreItems"
                label: qsTr("More items")
                icon: "expand_more"
                accessKey: "M"
                visible: pane.controller.cacheFull && !!pane.controller.nextCursor
                enabled: !pane.controller.loading && !pane.controller.modalOpen && !pane.controller.mutationBusy && !pane.controller.error
                onClicked: pane.controller.loadMore()
            }
        }
    }
    rowDelegate: Component { AgendaListRow { listPane: pane } }
}
