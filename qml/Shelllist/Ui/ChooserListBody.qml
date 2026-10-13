pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: body

    required property ChooserController chooserController
    required property Component rowDelegate
    property alias resultModel: listFrame.resultModel
    property alias listFooterComponent: listFrame.footerComponent
    property alias preserveViewportOnAppend: listFrame.preserveViewportOnAppend
    readonly property bool listNearEnd: listFrame.nearEnd
    property alias selectedIndex: listFrame.selectedIndex
    property alias emptyText: listFrame.emptyText
    property alias emptyIcon: listFrame.emptyIcon
    property alias emptyState: listFrame.emptyState
    property string status: ""
    property alias statusSummary: statusPanel.statusSummary
    property alias statusTone: statusPanel.statusTone
    property alias feedbackScope: statusPanel.feedbackScope
    property alias icon: statusPanel.icon
    property alias signalIcon: statusPanel.signalIcon
    property alias powered: statusPanel.powered
    property alias busy: statusPanel.busy
    property int bodySpacing: 0
    readonly property real delegateHeight: listFrame.delegateHeight
    readonly property bool listFocused: listFrame.listFocused
    readonly property int resultCount: listFrame.count

    function viewportState(): var { return listFrame.viewportState(); }
    function restoreViewport(state: var): void { listFrame.restoreViewport(state); }

    function focusList(): void {
        listFrame.focusList();
    }
    function focusTop(): void {
        listFrame.focusTop();
    }
    function pick(rowIndex: int): void {
        listFrame.pick(rowIndex);
    }
    function toggleDetails(rowIndex: int): void {
        listFrame.toggleDetails(rowIndex);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: body.bodySpacing

        ResultListFrame {
            id: listFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            uiScale: 1
            controller: body.chooserController
            // Preserve operation/screenshot/error ownership of the footer. If
            // occupied, keep the missing-content reason visible beside its icon.
            emptyShowLabel: body.status.length > 0 && body.status !== body.emptyText
            rowDelegate: body.rowDelegate
            onKeyPressed: function (event) {
                body.chooserController.navigation.handleListKey(event);
            }
        }

        // Keep domain progress/errors; a result count cannot replace these.
        StatusPanel {
            id: statusPanel
            Layout.fillWidth: true
            uiScale: 1
            status: body.status || (listFrame.count === 0 ? body.emptyText : "")
        }
    }
}
