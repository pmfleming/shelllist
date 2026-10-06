pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root
    required property BarController controller
    implicitWidth: 32
    implicitHeight: 37

    Ui.FlatIconButton {
        objectName: "barTrayButton"
        width: 32
        height: width
        anchors.centerIn: parent
        icon: "more_horiz"
        accessibleName: qsTr("Open Tray")
        activeFocusOnTab: false
        browseIndicatorVisible: false
        backgroundColor: "transparent"
        border.width: 0
        onClicked: root.controller.openSurface("tray")
    }
}
