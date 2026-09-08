pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section
    required property BluetoothController controller
    readonly property var policy: controller.selectedDevice.policy || ({})
    readonly property var settings: [
        { id: "reconnect_on_resume", label: "Reconnect after resume" },
        { id: "trust_after_pair", label: "Trust after pairing" },
        { id: "power_on_connect", label: "Power adapter when connecting" },
        { id: "wait_for_services", label: "Wait for services" }
    ]
    readonly property var actions: settings.map(function (setting) {
        return { id: setting.id, label: setting.label, state: { checked: section.policy[setting.id] !== false }, enabled: !section.controller.actionInFlight };
    }).concat([{
        id: "audio_route_on_connect", label: "Use as default output on connect",
        state: { checked: policy.audio_route_on_connect === "switch" }, enabled: !controller.actionInFlight
    }])
    readonly property var profileOptions: [{ value: "", label: "No profile override" }].concat(controller.selectedAudioProfiles.map(function (profile) {
        return { value: profile.key, label: profile.label, enabled: profile.available !== false };
    }))

    spacing: Ui.Theme.spacingSm
    Text {
        Layout.fillWidth: true
        text: "Effective device settings. Changes override defaults; Reset restores inheritance."
        wrapMode: Text.WordWrap
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.ActionToggleList {
        Layout.fillWidth: true
        actions: section.actions
        onTriggered: function (field) {
            const values = ({});
            values[field] = field === "audio_route_on_connect"
                ? (section.policy[field] === "switch" ? "keep" : "switch") : section.policy[field] === false;
            section.controller.updateDevicePolicy(values);
        }
    }
    Ui.FieldLabel { text: "Preferred audio profile on connect" }
    Ui.DropDownList {
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        options: section.profileOptions
        value: section.policy.preferred_audio_profile_key || ""
        placeholder: section.policy.preferred_audio_profile_key ? "Saved profile (currently unavailable)" : "No profile override"
        interactive: !section.controller.actionInFlight
        onSelected: function (key) { section.controller.updateDevicePolicy({ preferred_audio_profile_key: key || null }); }
    }
}
