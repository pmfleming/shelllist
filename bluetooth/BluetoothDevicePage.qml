import QtQuick
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery

Flickable {
    id: page

    required property BluetoothController controller
    readonly property alias editingName: settings.editingName
    readonly property var batteryReports: BluetoothBattery.ordered(controller.selectedDevice.battery || [])

    contentWidth: width
    contentHeight: cards.implicitHeight
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    clip: true

    Column {
        id: cards

        width: page.width
        spacing: Ui.Theme.spacingMd

        Ui.DetailCard {
            height: 190
            title: "Device overview"

            Ui.DetailGrid {
                entries: [
                    { label: "Connection", value: page.controller.selectedResult ? page.controller.selectedResult.subtitle : "—", valueColor: page.controller.selectedDevice.connected ? Ui.Theme.active : Ui.Theme.text, valueBold: page.controller.selectedDevice.connected },
                    { label: "Paired", value: page.controller.selectedDevice.paired ? "Yes" : "No" },
                    { label: "Trusted", value: page.controller.selectedDevice.trusted ? "Yes" : "No" },
                    { label: "In range", value: page.controller.selectedDevice.present ? "Yes" : "No" },
                    { label: "Services", value: page.controller.selectedDevice.services_resolved ? "Resolved" : "Pending" },
                    { label: "Audio profile", value: page.controller.activeAudioProfile.label || "—" }
                ]
            }
        }

        Ui.DetailCard {
            visible: page.batteryReports.length > 0
            height: visible ? Math.max(120, 76 + Math.ceil(page.batteryReports.length / 2) * 48) : 0
            title: page.batteryReports.length > 1 ? "Component batteries" : "Battery"

            Ui.DetailGrid {
                entries: page.batteryReports.map(function (battery) {
                    return {
                        label: battery.label || battery.component || "Battery",
                        value: battery.percentage + "%",
                        valueColor: Ui.Theme.active,
                        valueBold: true
                    };
                })
            }
        }

        Ui.DetailCard {
            height: 320
            title: "Device settings"

            BluetoothDeviceActions {
                id: settings
                anchors.fill: parent
                controller: page.controller
            }
        }

        Ui.DetailCard {
            height: 260
            title: "Technical details"

            Ui.DetailGrid {
                entries: [
                    { label: "Address", value: page.controller.selectedDevice.address || "Unavailable" },
                    { label: "Address type", value: page.controller.selectedDevice.address_type || "Unavailable" },
                    { label: "Adapter", value: page.controller.selectedAdapter.alias || page.controller.selectedAdapter.name || "Unavailable" },
                    { label: "RSSI", value: page.controller.selectedDevice.rssi === null || page.controller.selectedDevice.rssi === undefined ? "Unavailable" : page.controller.selectedDevice.rssi + " dBm" },
                    { label: "Last seen", value: page.controller.selectedDevice.last_seen_ms ? new Date(page.controller.selectedDevice.last_seen_ms).toLocaleString() : "Not observed this session" },
                    { label: "Modalias", value: page.controller.selectedDevice.modalias || "Unavailable" },
                    { label: "Adapter address", value: page.controller.selectedAdapter.address || "Unavailable" },
                    { label: "UUID count", value: String((page.controller.selectedDevice.uuids || []).length) }
                ]
            }
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
}
