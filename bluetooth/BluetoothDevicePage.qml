import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property alias editingName: settings.editingName
    readonly property bool hasAudio: !!controller.selectedAudio.device_key
    readonly property bool hasAudioProfiles: controller.selectedAudioProfiles.length > 0

    function routeLabel(route, available) {
        if (!available)
            return "Not provided";
        if (!route.ready)
            return "Unavailable";
        return route.is_default ? "Ready · default" : "Ready";
    }

    Item {
        width: parent.width
        height: noiseControl.visible
            ? noiseControl.y + noiseControl.implicitHeight : batteryStatus.implicitHeight

        BluetoothBatteryStatus {
            id: batteryStatus

            width: parent.width
            height: implicitHeight
            device: page.controller.selectedDevice
        }

        BluetoothNoiseControl {
            id: noiseControl

            width: parent.width
            height: implicitHeight
            // Account for the icon's top padding so exactly its top third overlaps.
            y: batteryStatus.height - iconExtent / 3 - Ui.Theme.spacingSm
            controller: page.controller
            referenceArtworkSize: batteryStatus.artworkSize
        }
    }

    Ui.DetailColumnCard {
        visible: page.hasAudio
        height: visible ? 190 : 0
        title: "Audio profile"
        contentSpacing: Ui.Theme.spacingMd

        Ui.DropDownList {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: page.controller.selectedAudioProfiles.map(function (profile) {
                return { value: profile.key, label: profile.label, enabled: profile.available !== false };
            })
            value: page.controller.selectedAudio.active_profile_key || ""
            placeholder: page.hasAudioProfiles ? "Select audio profile" : "No audio profiles available"
            interactive: !page.controller.actionInFlight && page.hasAudioProfiles
            onSelected: function (value) {
                const profile = page.controller.selectedAudioProfiles.find(function (entry) { return entry.key === value; });
                if (profile) page.controller.setAudioProfile(profile);
            }
        }

        Ui.DetailGrid {
            Layout.fillWidth: true
            Layout.fillHeight: true
            entries: [
                { label: "Active codec", value: page.controller.activeAudioProfile.codec || page.controller.activeAudioProfile.label || "Unavailable" },
                { label: "Available profiles", value: String(page.controller.selectedAudioProfiles.length) },
                { label: "Output", value: page.routeLabel(page.controller.selectedSink, page.controller.selectedAudio.sink !== null && page.controller.selectedAudio.sink !== undefined) },
                { label: "Input", value: page.routeLabel(page.controller.selectedSource, page.controller.selectedAudio.source !== null && page.controller.selectedAudio.source !== undefined) }
            ]
        }
    }

    Ui.DetailCard {
        height: settings.implicitHeight + 64
        title: "Device settings"

        BluetoothDeviceActions {
            id: settings
            anchors.fill: parent
            controller: page.controller
        }
    }
}
