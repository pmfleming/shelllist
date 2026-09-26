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
    function requestRefresh(): void {
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

    preserveViewportOnAppend: true
    readonly property bool shouldLoadMore: visible && listNearEnd && controller.canAutoLoadMoreHistory
    onShouldLoadMoreChanged: if (shouldLoadMore)
        Qt.callLater(loadNextPage)

    function loadNextPage(): void {
        if (shouldLoadMore)
            controller.loadMoreHistory();
    }

    listFooterComponent: Component {
        Item {
            id: footer
            objectName: "clipboardPagingFooter"
            width: ListView.view ? ListView.view.width : 0
            height: pane.controller.loadingMoreHistory || pane.controller.historyPageError.length > 0 ? Ui.Theme.controlHeight + Ui.Theme.spacingMd : 0
            visible: height > 0

            Text {
                anchors.centerIn: parent
                visible: pane.controller.loadingMoreHistory
                text: "Loading more…"
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                Accessible.role: Accessible.StaticText
                Accessible.name: text
            }

            Ui.ActionButton {
                objectName: "retryClipboardHistory"
                anchors.centerIn: parent
                width: Math.min(footer.width, 280)
                visible: pane.controller.historyPageError.length > 0
                label: "Couldn’t load more · Retry"
                toolTip: pane.controller.historyPageError
                backgroundColor: "transparent"
                borderColor: "transparent"
                onClicked: pane.controller.loadMoreHistory()
            }
        }
    }

    rowDelegate: Component {
        ClipboardListRow {
            listPane: pane
            controller: pane.controller
        }
    }
}
