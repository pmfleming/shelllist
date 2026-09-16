import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing

    ColumnLayout {
        width: parent.width
        spacing: Ui.Theme.spacingMd

        BluetoothListOptions {
            Layout.fillWidth: true
            controller: page.controller
        }
        BluetoothAdapterSettings {
            id: settings
            Layout.fillWidth: true
            controller: page.controller
        }
    }
}
