pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editingName: renameInput.inputActiveFocus
    property string displayedDeviceKey: ""
    property bool renameDirty: false
    readonly property bool renameValid: renameInput.text.trim().length > 0

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingSm

    function syncDeviceName(force) {
        const nextKey = controller.selectedDevice.key || "";
        const deviceChanged = nextKey !== displayedDeviceKey;
        if (deviceChanged) {
            renameAutoSaveTimer.stop();
            renameDirty = false;
        }
        displayedDeviceKey = nextKey;
        if (force || deviceChanged || !renameDirty)
            renameInput.text = controller.selectedDevice.name || "";
    }

    function queueRename() {
        renameDirty = true;
        controller.status = "Bluetooth device name change pending…";
        renameAutoSaveTimer.restart();
    }

    function saveRename() {
        renameAutoSaveTimer.stop();
        if (!renameDirty || !controller.hasSelection)
            return;
        const alias = renameInput.text.trim();
        if (!renameValid) {
            controller.status = "Enter a non-empty Bluetooth device name.";
            return;
        }
        if (alias === (controller.selectedDevice.name || "")) {
            renameDirty = false;
            return;
        }
        if (controller.actionInFlight)
            return;
        if (controller.renameSelected(alias))
            renameDirty = false;
    }

    Component.onCompleted: Qt.callLater(function () { section.syncDeviceName(true); })
    Component.onDestruction: section.saveRename()

    Timer {
        id: renameAutoSaveTimer
        interval: 700
        repeat: false
        onTriggered: section.saveRename()
    }

    Connections {
        target: section.controller
        function onSelectedResultChanged() { section.syncDeviceName(false); }
        function onActionInFlightChanged() {
            if (!section.controller.actionInFlight && section.renameDirty)
                renameAutoSaveTimer.restart();
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: qsTr("Device name")
        }

        Ui.ThemeText {
            Layout.maximumWidth: Math.round(section.width * 0.55)
            text: section.controller.selectedDevice.remote_name
                ? "Original: " + section.controller.selectedDevice.remote_name
                : "Original name unavailable"
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm

        Ui.TextField {
            id: renameInput
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            text: ""
            maximumLength: 248
            inputValid: section.renameValid
            readOnly: section.controller.actionInFlight
                || !(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_rename)
            onEdited: section.queueRename()
            onEditingFinished: section.saveRename()
            onAccepted: section.saveRename()
        }

        Ui.ActionButton {
            Layout.preferredWidth: 84
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Reset"
            enabled: !section.controller.actionInFlight
                && !!section.controller.selectedDevice.remote_name
                && section.controller.selectedDevice.alias !== section.controller.selectedDevice.remote_name
            onClicked: section.controller.resetSelectedName()
        }
    }

    Ui.ActionToggleList {
        Layout.fillWidth: true
        actions: section.controller.detailActions.filter(function (action) {
            return action.visible !== false && (action.presentation || {}).group === "settings";
        })
        onTriggered: function (actionId) { section.controller.triggerDetailAction(actionId); }
    }
}
