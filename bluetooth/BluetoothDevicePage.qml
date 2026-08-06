import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editingName: settings.editingName

    BluetoothBatteryStatus {
        id: batteryStatus

        width: parent.width
        device: page.controller.selectedDevice
    }

    BluetoothNoiseControl {
        width: parent.width
        controller: page.controller
        referenceArtworkSize: batteryStatus.artworkSize
    }

    Ui.DetailCard {
        height: 220
        title: "Device overview"
        entries: [
            { label: "Connection", value: page.controller.hasSelection ? BluetoothFlow.deviceState(page.controller.selectedDevice) : "—", valueColor: page.controller.selectedDevice.blocked ? Ui.Theme.danger : (page.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.text), valueBold: page.controller.selectedDevice.connected || page.controller.selectedDevice.blocked },
            { label: "Type", value: page.controller.selectedDevice.device_type || "Bluetooth device" },
            { label: "Paired", value: page.controller.selectedDevice.paired ? "Yes" : "No" },
            { label: "Trusted", value: page.controller.selectedDevice.trusted ? "Yes" : "No" },
            { label: "In range", value: page.controller.selectedDevice.present ? "Yes" : "No" },
            { label: "Services", value: page.controller.selectedDevice.services_resolved ? "Resolved" : "Pending" },
            { label: "Last error", value: page.controller.selectedOperationError
                ? (page.controller.selectedOperationError.message || "Operation failed") : "None",
                valueColor: page.controller.selectedOperationError ? Ui.Theme.danger : Ui.Theme.text }
        ]
    }

    Ui.DetailCard {
        height: Math.max(370, settings.implicitHeight + 76)
        title: "Device settings"

        BluetoothDeviceActions {
            id: settings
            anchors.fill: parent
            controller: page.controller
        }
    }

    Ui.DetailCard {
        height: 300
        title: "Technical details"
        entries: [
            { label: "Original name", value: page.controller.selectedDevice.remote_name || "Unavailable" },
            { label: "Address", value: page.controller.selectedDevice.address || "Unavailable" },
            { label: "Address type", value: page.controller.selectedDevice.address_type || "Unavailable" },
            { label: "Adapter", value: page.controller.selectedAdapter.alias || page.controller.selectedAdapter.name || "Unavailable" },
            { label: "Signal", value: BluetoothFlow.signalLabel(page.controller.selectedDevice) },
            { label: "RSSI", value: page.controller.selectedDevice.rssi === null || page.controller.selectedDevice.rssi === undefined ? "Unavailable" : page.controller.selectedDevice.rssi + " dBm" + (page.controller.selectedDevice.signal_live ? "" : " (cached)") },
            { label: "Last seen", value: page.controller.selectedDevice.last_seen_ms ? new Date(page.controller.selectedDevice.last_seen_ms).toLocaleString() : "Not observed this session" },
            { label: "Modalias", value: page.controller.selectedDevice.modalias || "Unavailable" },
            { label: "Adapter address", value: page.controller.selectedAdapter.address || "Unavailable" },
            { label: "UUID count", value: String((page.controller.selectedDevice.uuids || []).length) }
        ]
    }

    Ui.DetailCard {
        visible: !!(page.controller.selectedDevice.services && page.controller.selectedDevice.services.length)
        height: visible ? Math.max(110, servicesText.implicitHeight + 72) : 0
        title: "Services"

        Text {
            id: servicesText
            anchors.fill: parent
            text: (page.controller.selectedDevice.services || []).map(function (service) { return service.label; }).filter(function (label, index, values) { return values.indexOf(label) === index; }).join(" · ")
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
            wrapMode: Text.WordWrap
        }
    }
}
