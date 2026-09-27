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
    property string status: ""
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool busy: false
    property real listInset: 0
    property int bodySpacing: 0
    readonly property real delegateHeight: listFrame.delegateHeight
    readonly property bool listFocused: listFrame.listFocused

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
        anchors.leftMargin: body.listInset
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
            rowDelegate: body.rowDelegate
            onKeyPressed: function (event) {
                body.chooserController.navigation.handleListKey(event);
            }
        }

        StatusPanel {
            Layout.fillWidth: true
            uiScale: 1
            status: body.status
            icon: body.icon
            signalIcon: body.signalIcon
            powered: body.powered
            busy: body.busy
        }
    }
}
