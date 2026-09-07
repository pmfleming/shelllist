import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothNoiseControl.js" as NoiseControl

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
        height: visible ? 240 : 0
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

        RowLayout {
            Layout.fillWidth: true
            Ui.ActionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: "Use as output"
                enabled: !page.controller.actionInFlight && !!page.controller.selectedSink.ready && !page.controller.selectedSink.is_default
                onClicked: page.controller.setAudioDefault(page.controller.selectedSink)
            }
            Ui.ActionButton {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: "Use as input"
                enabled: !page.controller.actionInFlight && !!page.controller.selectedSource.ready && !page.controller.selectedSource.is_default
                onClicked: page.controller.setAudioDefault(page.controller.selectedSource)
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

    Ui.DetailColumnCard {
        id: soundCard
        readonly property var control: (page.controller.selectedDevice.fast_pair || {}).noise_control || ({})
        readonly property var caps: page.controller.selectedDevice.capabilities || ({})
        visible: NoiseControl.isAdvertised(control)
        height: visible ? 155 : 0
        title: "Sound isolation control"
        Ui.DropDownList {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: NoiseControl.availableModes(soundCard.control).map(function (mode) {
                return { value: mode.value, label: mode.label, enabled: (soundCard.control.settable_modes || []).includes(mode.value) };
            })
            value: soundCard.control.active_mode || ""
            interactive: !page.controller.actionInFlight && !!soundCard.caps.can_set_noise_control
            onSelected: function (mode) { page.controller.setNoiseControl(mode); }
        }
        Text {
            Layout.fillWidth: true
            text: soundCard.caps.can_set_noise_control ? "Only modes currently allowed by the earbuds can be selected."
                : ((soundCard.caps.unsupported_reasons || {}).set_noise_control || "Fast Pair account-key provisioning is required.")
            wrapMode: Text.WordWrap
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }

    Ui.DetailCard {
        visible: !!page.controller.selectedDevice.fast_pair
        height: visible ? fastPairSetup.implicitHeight + 64 : 0
        title: "Fast Pair setup"
        BluetoothFastPairSetup {
            id: fastPairSetup
            anchors.fill: parent
            controller: page.controller
        }
    }

    Ui.DetailCard {
        height: devicePolicy.implicitHeight + 64
        title: "Connection policy"
        BluetoothDevicePolicy {
            id: devicePolicy
            anchors.fill: parent
            controller: page.controller
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
