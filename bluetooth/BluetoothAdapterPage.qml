import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing

    Ui.DetailCard {
        height: 440
        title: "Adapter settings"

        BluetoothAdapterSettings {
            id: settings
            anchors.fill: parent
            controller: page.controller
        }
    }

    Ui.DetailCard {
        height: 150
        title: "Adapter details"
        entries: [
            { label: "Controller", value: page.controller.selectedAdapter.name || "Unavailable" },
            { label: "Alias", value: page.controller.selectedAdapter.alias || "Unavailable" },
            { label: "Address", value: page.controller.selectedAdapter.address || "Unavailable" },
            { label: "Modalias", value: page.controller.selectedAdapter.modalias || "Unavailable" }
        ]
    }
}
