import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing

    BluetoothAdapterSettings {
        id: settings
        width: parent.width
        controller: page.controller
    }
}
