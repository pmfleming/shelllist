import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: page

    required property BluetoothController controller
    readonly property var transferActions: [
        {
            id: "send-file", label: "Send file", icon: "󰈔", visible: !!controller.obexCapabilities.outgoing_object_push && !controller.canCancelTransfer,
            enabled: !!(controller.selectedDevice.capabilities && controller.selectedDevice.capabilities.can_send_file) && !controller.actionInFlight,
            presentation: { group: "toolbar", tone: "normal", width: 116 }
        },
        {
            id: "cancel-transfer", label: "Cancel transfer", icon: "󰜺", visible: controller.canCancelTransfer,
            enabled: controller.canCancelTransfer, presentation: { group: "toolbar", tone: "danger", width: 148 }
        },
        {
            id: "cancel-operation", label: "Cancel operation", icon: "󰜺", visible: controller.canCancelOperation,
            enabled: controller.canCancelOperation, presentation: { group: "toolbar", tone: "danger", width: 156 }
        }
    ]

    function localFilePath(url) {
        const value = url.toString();
        return value.indexOf("file://") === 0 ? decodeURIComponent(value.slice(7)) : value;
    }
    function triggerTransferAction(actionId) {
        if (actionId === "send-file") outgoingFileDialog.open();
        else if (actionId === "cancel-transfer") controller.cancelActiveTransfer();
        else if (actionId === "cancel-operation") controller.cancelActiveOperation();
    }

    FileDialog {
        id: outgoingFileDialog
        title: "Send file over Bluetooth"
        fileMode: FileDialog.OpenFile
        onAccepted: page.controller.sendFile(page.localFilePath(selectedFile))
    }

    Ui.DetailCard {
        height: 126
        title: "File transfer"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm

            Text {
                Layout.fillWidth: true
                text: page.controller.activeTransfer ? page.controller.status
                    : (page.controller.obexCapabilities.outgoing_object_push ? "Ready to send files" : "Object push is unavailable")
                color: page.controller.activeTransfer ? Ui.Theme.accent : Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
                elide: Text.ElideRight
            }
            Ui.ActionToolbar {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                actions: page.transferActions
                group: "toolbar"
                controlHeight: Ui.Theme.compactControlHeight
                onTriggered: function (actionId) { page.triggerTransferAction(actionId); }
            }
        }
    }

    Ui.DetailCard {
        height: 190
        title: "Audio profile"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingMd

            Ui.SegmentedControl {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                options: page.controller.selectedAudioProfiles.map(function (profile) { return { value: profile.key, label: profile.label }; })
                value: page.controller.selectedAudio.active_profile_key || ""
                interactive: !page.controller.actionInFlight && page.controller.selectedAudioProfiles.length > 0
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
                    { label: "Output", value: page.controller.selectedSink.ready ? (page.controller.selectedSink.is_default ? "Ready · default" : "Ready") : "Not ready", valueColor: page.controller.selectedSink.ready ? Ui.Theme.text : Ui.Theme.danger },
                    { label: "Input", value: page.controller.selectedSource.ready ? (page.controller.selectedSource.is_default ? "Ready · default" : "Ready") : "Not ready", valueColor: page.controller.selectedSource.ready ? Ui.Theme.text : Ui.Theme.danger }
                ]
            }
        }
    }

    Ui.DetailCard {
        height: 150
        title: "Runtime state"
        entries: [
            { label: "Output state", value: page.controller.selectedSink.state || "Unknown" },
            { label: "Input state", value: page.controller.selectedSource.state || "Unknown" },
            { label: "Audio service", value: page.controller.audioStatus || "Ready", valueColor: page.controller.audioStatus.length > 0 ? Ui.Theme.danger : Ui.Theme.text },
            { label: "OBEX", value: page.controller.obexCapabilities.available ? "Available" : "Unavailable" }
        ]
    }
}
