import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: card

    required property BluetoothController controller
    readonly property var policy: controller.selectedDevice.policy || ({})
    readonly property bool hasAudio: !!controller.selectedAudio.device_key
    readonly property bool hasProfiles: controller.selectedAudioProfiles.length > 0
    readonly property bool audioDevice: hasAudio
        || /headphone|headset|speaker|audio/i.test(controller.selectedDevice.device_type || "")
        || !!((controller.selectedDevice.fast_pair || {}).multipoint || {}).supported
        || !!policy.preferred_audio_profile_key || policy.audio_route_on_connect === "switch"
    readonly property var profileOptions: [{value: "", label: "No profile override"}].concat(
        controller.selectedAudioProfiles.map(function (profile) {
            return {value: profile.key, label: profile.label, enabled: profile.available !== false};
        }))

    objectName: "deviceAudio"
    title: qsTr("Audio")
    visible: audioDevice
    height: visible ? implicitHeight : 0
    contentSpacing: Ui.Theme.spacingMd

    ColumnLayout {
        Layout.fillWidth: true
        visible: card.hasAudio
        spacing: Ui.Theme.spacingSm

        Ui.FieldLabel { text: qsTr("Now · Audio profile") }
        Ui.DropDownList {
            objectName: "currentAudioProfile"
            Layout.fillWidth: true
            options: card.controller.selectedAudioProfiles.map(function (profile) {
                return {value: profile.key, label: profile.label, enabled: profile.available !== false};
            })
            value: card.controller.selectedAudio.active_profile_key || ""
            placeholder: card.hasProfiles ? "Select audio profile" : "No audio profiles available"
            interactive: !card.controller.actionInFlight && card.hasProfiles
            onSelected: function (value) {
                const profile = card.controller.selectedAudioProfiles.find(function (entry) { return entry.key === value; });
                if (profile)
                    card.controller.setAudioProfile(profile);
            }
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            visible: !!card.controller.activeAudioProfile.codec
            text: "Codec: " + (card.controller.activeAudioProfile.codec || "")
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }

        RowLayout {
            Layout.fillWidth: true
            Ui.ActionButton {
                objectName: "useAudioOutput"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: card.controller.selectedSink.is_default ? "Default output" : "Use as output"
                toolTip: card.controller.selectedSink.ready ? "" : "Audio output is not available"
                enabled: !card.controller.actionInFlight && !!card.controller.selectedSink.ready && !card.controller.selectedSink.is_default
                onClicked: card.controller.setAudioDefault(card.controller.selectedSink)
            }
            Ui.ActionButton {
                objectName: "useAudioInput"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: card.controller.selectedSource.is_default ? "Default input" : "Use as input"
                toolTip: card.controller.selectedSource.ready ? "" : "Audio input is not available"
                enabled: !card.controller.actionInFlight && !!card.controller.selectedSource.ready && !card.controller.selectedSource.is_default
                onClicked: card.controller.setAudioDefault(card.controller.selectedSource)
            }
        }
    }

    Ui.ActionToggleList {
        Layout.fillWidth: true
        visible: actions.length > 0
        showDisabledReason: !card.controller.actionInFlight
        actions: card.controller.detailActions.filter(function (action) {
            return action.visible !== false && action.id === "multipoint";
        })
        onTriggered: function (actionId) { card.controller.triggerDetailAction(actionId); }
    }

    Ui.FieldLabel { text: qsTr("On connection") }
    Ui.ToggleRow {
        objectName: "audioOutputOnConnect"
        Layout.fillWidth: true
        title: qsTr("Make default output")
        checked: card.policy.audio_route_on_connect === "switch"
        interactive: !card.controller.actionInFlight
        onClicked: card.controller.updateDevicePolicy({audio_route_on_connect: checked ? "keep" : "switch"})
    }
    Ui.FieldLabel { text: qsTr("Preferred profile") }
    Ui.DropDownList {
        objectName: "audioProfileOnConnect"
        Layout.fillWidth: true
        options: card.profileOptions
        value: card.policy.preferred_audio_profile_key || ""
        placeholder: "Saved profile (currently unavailable)"
        interactive: !card.controller.actionInFlight
        onSelected: function (key) {
            card.controller.updateDevicePolicy({preferred_audio_profile_key: key || null});
        }
    }
}
