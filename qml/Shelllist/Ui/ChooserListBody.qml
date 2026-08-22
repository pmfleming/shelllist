pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

Item {
    id: body

    required property ChooserController chooserController
    required property Component rowDelegate
    required property real densityScale
    property var resultModel: null
    property int selectedIndex: 0
    property string emptyText: ""
    property Component toolbarComponent: null
    property int toolbarHeight: 0
    property string status: ""
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool busy: false
    property real listInset: 0
    property int bodySpacing: 0
    readonly property real delegateHeight: listFrame.delegateHeight
    readonly property bool listFocused: listFrame.listFocused

    function focusTop(): void { listFrame.focusTop(); }
    function pick(rowIndex: int): void { listFrame.pick(rowIndex); }
    function toggleDetails(rowIndex: int): void { listFrame.toggleDetails(rowIndex); }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: body.listInset
        spacing: body.bodySpacing

        ResultListFrame {
            id: listFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            uiScale: body.densityScale
            controller: body.chooserController
            resultModel: body.resultModel
            selectedIndex: body.selectedIndex
            emptyText: body.emptyText
            rowDelegate: body.rowDelegate
            onKeyPressed: function (event) {
                body.chooserController.navigation.handleListKey(event);
            }
        }

        Loader {
            Layout.fillWidth: true
            Layout.preferredHeight: active ? body.toolbarHeight : 0
            active: body.toolbarComponent !== null
            sourceComponent: body.toolbarComponent
        }

        StatusPanel {
            Layout.fillWidth: true
            uiScale: body.densityScale
            status: body.status
            icon: body.icon
            signalIcon: body.signalIcon
            powered: body.powered
            busy: body.busy
        }
    }
}
