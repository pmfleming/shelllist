import QtQuick
import Shelllist.Ui as Ui

Ui.SegmentedControl {
    property string accessibleName: qsTr("Power profile")
    circular: true
    iconOnly: true
    Accessible.name: accessibleName
}
