pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editingName: renameInput.inputActiveFocus
    property string displayedDeviceKey: ""
    readonly property var draft: controller.nameEdits.draft(displayedDeviceKey)
    readonly property bool renameDirty: !!draft && draft.dirty
    readonly property bool renameValid: renameInput.text.trim().length > 0

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingSm

    function syncDeviceName(force) {
        const nextKey = controller.selectedDevice.key || "";
        const deviceChanged = nextKey !== displayedDeviceKey;
        if (deviceChanged)
            renameAutoSaveTimer.stop();
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

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: qsTr("Device name")
        }

        Ui.ThemeText {
            Layout.maximumWidth: Math.round(section.width * 0.55)
            visible: !!section.controller.selectedDevice.remote_name && section.controller.selectedDevice.name !== section.controller.selectedDevice.remote_name
            text: "Original: " + (section.controller.selectedDevice.remote_name || "")
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
            objectName: "deviceNameInput"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            text: ""
            maximumLength: 248
            inputValid: section.renameValid
            readOnly: section.controller.actionInFlight || !(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_rename)
            onEdited: section.queueRename()
            onEditingFinished: section.saveRename()
            onAccepted: section.saveRename()
        }

        Ui.ActionButton {
            objectName: "restoreDeviceName"
            Layout.preferredWidth: 180
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: qsTr("Restore original name")
            enabled: !section.renameDirty && !section.controller.actionInFlight && !!section.controller.selectedDevice.remote_name && section.controller.selectedDevice.alias !== section.controller.selectedDevice.remote_name
            onClicked: section.controller.resetSelectedName()
        }
    }

    Ui.ThemeText {
        Layout.fillWidth: true
        visible: !!(section.draft || {}).error
        text: (section.draft || {}).error || ""
        wrapMode: Text.WordWrap
        color: Ui.Theme.danger
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!(section.draft || {}).error
        Ui.ActionButton {
            objectName: "retryDeviceName"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: qsTr("Retry rename")
            enabled: !section.controller.actionInFlight && section.renameValid
            onClicked: section.controller.nameEdits.retry(section.displayedDeviceKey)
        }
        Ui.ActionButton {
            objectName: "discardDeviceName"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
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
        actions: section.controller.detailActions.filter(function (action) {
            return action.visible !== false && action.id !== "multipoint" && (action.presentation || {}).group === "settings";
        })
        onTriggered: function (actionId) {
            section.controller.triggerDetailAction(actionId);
        }
    }
}
