import QtQuick
import Shelllist.Ui as Ui

Ui.SegmentedControl {
    property string accessibleName: qsTr("Power profile")
    implicitWidth: 300
    Accessible.name: accessibleName
}
