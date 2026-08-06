import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editing: settings.editing

    Ui.DetailCard {
        height: Math.max(700, settings.implicitHeight + 76)
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
            { label: "Modalias", value: page.controller.selectedAdapter.modalias || "Unavailable" },
            { label: "Radio state", value: page.controller.radio.hard_blocked ? "Hardware blocked"
                : (page.controller.radio.soft_blocked ? "Soft blocked"
                : (page.controller.radio.operational ? "Operational" : "Offline")) }
        ]
    }
}
