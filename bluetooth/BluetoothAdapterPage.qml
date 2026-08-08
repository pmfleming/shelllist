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

    Ui.DetailCard {
        height: 150
        title: "Adapter information"
        entries: [
            { label: "Controller", value: page.controller.selectedAdapter.name || "Unavailable" },
            { label: "Address", value: page.controller.selectedAdapter.address || "Unavailable" },
            { label: "Modalias", value: page.controller.selectedAdapter.modalias || "Unavailable" },
            { label: "Radio state", value: page.controller.radio.hard_blocked ? "Hardware blocked"
                : (page.controller.radio.soft_blocked ? "Soft blocked"
                : (page.controller.radio.operational ? "Operational" : "Offline")) }
        ]
    }
}
