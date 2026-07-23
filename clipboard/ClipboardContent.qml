pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: content

    required property ClipboardController controller
    required property ClipboardWindowHost windowHost
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.window
    border.color: Ui.Theme.strongBorder
    border.width: 1

    Shortcut { sequence: "Escape"; onActivated: content.windowHost.closeRequested() }
    Shortcut { sequence: "F5"; onActivated: content.controller.refresh() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Math.round(10 * content.uiScale)

        Ui.ChooserHeader {
            id: header
            uiScale: content.uiScale
            placeholder: "Search clipboard…"
            icon: "󰅇"
            filterText: content.controller.filterText
            powered: true
            refreshing: content.controller.refreshInFlight
            powerEnabled: false
            refreshEnabled: !content.controller.refreshInFlight
            onFilterEdited: function (text) { content.controller.filterText = text; }
            onRefreshRequested: content.controller.refresh()
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Down) {
                    content.controller.moveSelection(1);
                    listFrame.focusList();
                    event.accepted = true;
                }
            }
        }

        Ui.ResultListFrame {
            id: listFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            uiScale: content.uiScale
            resultModel: content.controller.filteredResultsModel
            selectedIndex: content.controller.selectedIndex
            emptyText: content.controller.refreshInFlight ? "Loading clipboard history…" : "Clipboard history is empty"
            onKeyPressed: function (event) {
                if (event.key === Qt.Key_Down) {
                    content.controller.moveSelection(1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    if (content.controller.selectedIndex === 0)
                        header.focusSearch();
                    else
                        content.controller.moveSelection(-1);
                    event.accepted = true;
                }
            }
            rowDelegate: Component {
                ClipboardListRow {
                    rowHeight: listFrame.delegateHeight
                    uiScale: content.uiScale
                    selectedIndex: content.controller.selectedIndex
                    selectionFocused: listFrame.listFocused
                    onPicked: function (rowIndex) {
                        content.controller.selectedIndex = rowIndex;
                        listFrame.focusList();
                    }
                }
            }
        }

        Ui.StatusPanel {
            Layout.fillWidth: true
            uiScale: content.uiScale
            status: content.controller.status
            icon: "󰅇"
            powered: true
            busy: content.controller.refreshInFlight
        }
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(header.focusSearch); }
    }
}
