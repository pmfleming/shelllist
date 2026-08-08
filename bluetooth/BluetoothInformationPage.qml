import QtQuick
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property bool hasAudio: !!controller.selectedAudio.device_key
    readonly property bool hasSink: controller.selectedAudio.sink !== null
        && controller.selectedAudio.sink !== undefined
    readonly property bool hasSource: controller.selectedAudio.source !== null
        && controller.selectedAudio.source !== undefined

    function routeState(route, available) {
        if (!available)
            return "Not provided";
        const state = route.state || (route.ready ? "ready" : "unavailable");
        return route.is_default ? state + " · default" : state;
    }

    Ui.DetailCard {
        height: 190
        title: "Device status"
        entries: [
            { label: "Connection", value: BluetoothFlow.deviceState(page.controller.selectedDevice), valueColor: page.controller.selectedDevice.blocked ? Ui.Theme.danger : (page.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.text), valueBold: page.controller.selectedDevice.connected || page.controller.selectedDevice.blocked },
            { label: "Type", value: page.controller.selectedDevice.device_type || "Bluetooth device" },
            { label: "Paired", value: page.controller.selectedDevice.paired ? "Yes" : "No" },
            { label: "In range", value: page.controller.selectedDevice.present ? "Yes" : "No" },
            { label: "Signal", value: BluetoothFlow.signalLabel(page.controller.selectedDevice) },
            { label: "Last seen", value: page.controller.selectedDevice.last_seen_ms ? new Date(page.controller.selectedDevice.last_seen_ms).toLocaleString() : "Not observed this session" }
        ]
    }

    Ui.DetailCard {
        visible: page.hasAudio
        height: visible ? 190 : 0
        title: "Audio state"
        entries: [
            { label: "Profile", value: page.controller.activeAudioProfile.label || "Unavailable" },
            { label: "Codec", value: page.controller.activeAudioProfile.codec || "Unavailable" },
            { label: "Output", value: page.routeState(page.controller.selectedSink, page.hasSink) },
            { label: "Input", value: page.routeState(page.controller.selectedSource, page.hasSource) },
            { label: "Profiles", value: String(page.controller.selectedAudioProfiles.length) },
            { label: "Audio service", value: page.controller.audioStatus || "Ready", valueColor: page.controller.audioStatus.length > 0 ? Ui.Theme.danger : Ui.Theme.text }
        ]
    }

    Ui.DetailCard {
        height: 190
        title: "Device information"
        entries: [
            { label: "Original name", value: page.controller.selectedDevice.remote_name || "Unavailable" },
            { label: "Address", value: page.controller.selectedDevice.address || "Unavailable" },
            { label: "Address type", value: page.controller.selectedDevice.address_type || "Unavailable" },
            { label: "Adapter", value: page.controller.selectedAdapter.alias || page.controller.selectedAdapter.name || "Unavailable" },
            { label: "Modalias", value: page.controller.selectedDevice.modalias || "Unavailable" },
            { label: "Last error", value: page.controller.selectedOperationError ? (page.controller.selectedOperationError.message || "Operation failed") : "None", valueColor: page.controller.selectedOperationError ? Ui.Theme.danger : Ui.Theme.text }
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
