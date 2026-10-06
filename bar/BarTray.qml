pragma ComponentBehavior: Bound
import Quickshell.Services.SystemTray
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root
    required property BarController controller
    required property int layoutDensity
    readonly property int inlineLimit: layoutDensity === 0 ? 3 : layoutDensity === 1 ? 1 : 0
    implicitWidth: trayRow.implicitWidth
    implicitHeight: 37
    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
            model: Array.from(SystemTray.items.values).slice(0, root.inlineLimit)
            delegate: BarTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                height: root.height
            }
        }
        Ui.FlatIconButton {
            width: 32
            height: width
            anchors.verticalCenter: parent.verticalCenter
            icon: "more_horiz"
            accessibleName: qsTr("Open Tray")
            activeFocusOnTab: false
            backgroundColor: "transparent"
            border.width: 0
            onClicked: root.controller.openSurface("tray")
        }
    }
}
