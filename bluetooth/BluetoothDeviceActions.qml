pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editingName: renameInput.inputActiveFocus
    property string displayedDeviceKey: ""
    readonly property var draft: controller.nameEdits.draft(displayedDeviceKey)
    readonly property bool renameDirty: !!draft && draft.dirty
    readonly property bool renameValid: renameInput.text.trim().length > 0
    property bool validationAttempted: false

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingSm

    function syncDeviceName(force) {
        const nextKey = controller.selectedDevice.key || "";
        const deviceChanged = nextKey !== displayedDeviceKey;
        if (deviceChanged)
            renameAutoSaveTimer.stop();
        if (deviceChanged)
            validationAttempted = false;
        displayedDeviceKey = nextKey;
        const saved = controller.nameEdits.draft(nextKey);
        renameInput.text = saved ? saved.value : (controller.selectedDevice.name || "");
    }

    function queueRename() {
        controller.nameEdits.edit(displayedDeviceKey, renameInput.text);
        controller.status = "Bluetooth device name change pending…";
        renameAutoSaveTimer.restart();
    }

    function saveRename() {
        validationAttempted = true;
        renameAutoSaveTimer.stop();
        if (!renameValid) {
            controller.status = "Enter a non-empty Bluetooth device name.";
            return;
        }
        controller.nameEdits.save(displayedDeviceKey);
    }

    Component.onCompleted: Qt.callLater(section.syncDeviceName, true)
    onDraftChanged: Qt.callLater(section.syncDeviceName, false)
    Component.onDestruction: if (renameDirty && !(draft || {}).pending && !(draft || {}).error)
        section.saveRename()

    Timer {
        id: renameAutoSaveTimer
        interval: 700
        repeat: false
        onTriggered: section.saveRename()
    }

    Connections {
        target: section.controller
        function onSelectedResultChanged() {
            section.syncDeviceName(false);
        }
        function onActionInFlightChanged() {
            if (!section.controller.actionInFlight && section.renameDirty && !(section.draft || {}).error)
                renameAutoSaveTimer.restart();
        }
    }

    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Device name")
        supportingText: section.controller.selectedDevice.remote_name && section.controller.selectedDevice.name !== section.controller.selectedDevice.remote_name ? qsTr("Original: %1").arg(section.controller.selectedDevice.remote_name) : ""
        statusText: (section.draft || {}).pending ? qsTr("Saving…") : ""
        errorText: (section.draft || {}).error || (section.validationAttempted && !section.renameValid ? qsTr("Enter a non-empty device name") : "")

        Ui.TextField {
            id: renameInput
            objectName: "deviceNameInput"
            Layout.fillWidth: true
            text: ""
            maximumLength: 248
            inputValid: !section.validationAttempted || section.renameValid
            readOnly: section.controller.actionInFlight || !(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_rename)
            onEdited: section.queueRename()
            onEditingFinished: section.saveRename()
            onAccepted: section.saveRename()
        }
    }

    Ui.LabeledAction {
        icon: "restore"
        objectName: "restoreDeviceName"
        accessKey: "O"
        Layout.fillWidth: true
        label: qsTr("Restore original name")
        enabled: !section.renameDirty && !section.controller.actionInFlight && !!section.controller.selectedDevice.remote_name && section.controller.selectedDevice.alias !== section.controller.selectedDevice.remote_name
        onClicked: section.controller.resetSelectedName()
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!(section.draft || {}).error
        Ui.LabeledAction {
            icon: "refresh"
            objectName: "retryDeviceName"
            accessKey: "N"
            Layout.fillWidth: true
            label: qsTr("Retry rename")
            enabled: !section.controller.actionInFlight && section.renameValid
            onClicked: section.controller.nameEdits.retry(section.displayedDeviceKey)
        }
        Ui.LabeledAction {
            icon: "undo"
            objectName: "discardDeviceName"
            accessKey: "X"
            Layout.fillWidth: true
            label: qsTr("Discard draft")
            enabled: !(section.draft || {}).pending
            onClicked: {
                section.controller.nameEdits.discard(section.displayedDeviceKey);
                section.syncDeviceName(true);
            }
        }
    }

    Ui.ActionToggleList {
        Layout.fillWidth: true
        showDisabledReason: !section.controller.actionInFlight
        actions: Core.Model.visibleActions(section.controller.detailActions, "settings").filter(action => action.id !== "multipoint")
        onTriggered: function (actionId) {
            section.controller.triggerDetailAction(actionId);
        }
    }
}
