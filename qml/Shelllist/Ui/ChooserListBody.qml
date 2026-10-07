pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: body

    required property ChooserController chooserController
    required property Component rowDelegate
    property var resultModel: null
    property Component listFooterComponent: null
    property bool preserveViewportOnAppend: false
    readonly property bool listNearEnd: listFrame.nearEnd
    property int selectedIndex: 0
    property string emptyText: ""
    property string emptyIcon: ""
    property string emptyState: "empty"
    property string status: ""
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool busy: false
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
            resultModel: body.resultModel
            footerComponent: body.listFooterComponent
            preserveViewportOnAppend: body.preserveViewportOnAppend
            selectedIndex: body.selectedIndex
            emptyText: body.emptyText
            emptyIcon: body.emptyIcon
            emptyState: body.emptyState
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
            visible: status.length > 0
            Layout.fillWidth: true
            uiScale: 1
            status: body.status || (listFrame.count === 0 ? body.emptyText : "")
            icon: body.icon
            signalIcon: body.signalIcon
            powered: body.powered
            busy: body.busy
        }
    }
}
