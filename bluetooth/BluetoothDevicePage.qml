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
        height: noiseControl.visible ? Math.max(batteryStatus.implicitHeight, noiseControl.y + noiseControl.implicitHeight) : batteryStatus.implicitHeight

        BluetoothBatteryStatus {
            id: batteryStatus

            width: parent.width - (noiseControl.visible ? noiseControl.iconExtent + Ui.Theme.spacingMd : 0)
            height: implicitHeight
            device: page.controller.selectedDevice
        }

        BluetoothNoiseControl {
            id: noiseControl

            anchors.right: parent.right
            width: iconExtent
            height: implicitHeight
            y: batteryStatus.percentageBottom - iconExtent
            controller: page.controller
            referenceArtworkSize: batteryStatus.artworkSize
        }
    }

    Ui.DetailColumnCard {
        visible: page.hasAudio
        height: visible ? 240 : 0
        title: qsTr("Audio profile")
        contentSpacing: Ui.Theme.spacingMd

        Ui.DropDownList {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: page.controller.selectedAudioProfiles.map(function (profile) {
                return {
                    value: profile.key,
                    label: profile.label,
                    enabled: profile.available !== false
                };
            })
            value: page.controller.selectedAudio.active_profile_key || ""
            placeholder: page.hasAudioProfiles ? "Select audio profile" : "No audio profiles available"
            interactive: !page.controller.actionInFlight && page.hasAudioProfiles
            onSelected: function (value) {
                const profile = page.controller.selectedAudioProfiles.find(function (entry) {
                    return entry.key === value;
                });
                if (profile)
                    page.controller.setAudioProfile(profile);
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
                {
                    label: "Active codec",
                    value: page.controller.activeAudioProfile.codec || page.controller.activeAudioProfile.label || "Unavailable"
                },
                {
                    label: "Available profiles",
                    value: String(page.controller.selectedAudioProfiles.length)
                },
                {
                    label: "Output",
                    value: page.routeLabel(page.controller.selectedSink, page.controller.selectedAudio.sink !== null && page.controller.selectedAudio.sink !== undefined)
                },
                {
                    label: "Input",
                    value: page.routeLabel(page.controller.selectedSource, page.controller.selectedAudio.source !== null && page.controller.selectedAudio.source !== undefined)
                }
            ]
        }
    }

    Ui.DetailCard {
        height: devicePolicy.implicitHeight + 64
        title: qsTr("Connection policy")
        BluetoothDevicePolicy {
            id: devicePolicy
            anchors.fill: parent
            controller: page.controller
        }
    }

    Ui.DetailCard {
        height: settings.implicitHeight + 64
        title: qsTr("Device settings")

        BluetoothDeviceActions {
            id: settings
            anchors.fill: parent
            controller: page.controller
        }
    }
}
