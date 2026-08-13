import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus
        || discoverableTimeoutRow.inputActiveFocus
        || pairableTimeoutRow.inputActiveFocus
    property string displayedAdapterKey: ""
    property bool aliasDirty: false
    property bool discoverableTimeoutDirty: false
    property bool pairableTimeoutDirty: false
    readonly property bool hasDirtyFields: aliasDirty || discoverableTimeoutDirty || pairableTimeoutDirty
    readonly property bool aliasValid: adapterAliasInput.text.trim().length > 0
    readonly property int maximumTimeout: 3600
    readonly property int timeoutStep: 30

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

    function clearDirtyFields() {
        aliasDirty = false;
        discoverableTimeoutDirty = false;
        pairableTimeoutDirty = false;
    }

    function syncAlias(force, adapter) {
        if (force || !aliasDirty) adapterAliasInput.text = adapter.alias || "";
    }
    function syncDiscoverableTimeout(force, adapter) {
        if (force || !discoverableTimeoutDirty)
            discoverableTimeoutRow.value = Math.min(maximumTimeout, Number(adapter.discoverable_timeout || 0));
    }
    function syncPairableTimeout(force, adapter) {
        if (force || !pairableTimeoutDirty)
            pairableTimeoutRow.value = Math.min(maximumTimeout, Number(adapter.pairable_timeout || 0));
    }
    function syncAdapterFields(force) {
        const adapter = controller.selectedAdapter;
        const nextKey = adapter.key || "";
        const adapterChanged = nextKey !== displayedAdapterKey;
        if (adapterChanged) {
            autoSaveTimer.stop();
            clearDirtyFields();
        }
        displayedAdapterKey = nextKey;
        const syncAll = force || adapterChanged;
        syncAlias(syncAll, adapter);
        syncDiscoverableTimeout(syncAll, adapter);
        syncPairableTimeout(syncAll, adapter);
    }

    function markAliasDirty() { aliasDirty = true; }
    function markDiscoverableTimeoutDirty() { discoverableTimeoutDirty = true; }
    function markPairableTimeoutDirty() { pairableTimeoutDirty = true; }
    function queueAutoSave(markDirty, debounce) {
        markDirty();
        controller.status = "Bluetooth adapter changes pending…";
        debounce === false ? autoSaveTimer.stop() : autoSaveTimer.restart();
    }

    function saveAliasIfDirty() {
        if (!aliasDirty)
            return false;
        const alias = adapterAliasInput.text.trim();
        if (!aliasValid) {
            controller.status = "Enter a non-empty Bluetooth adapter alias.";
            return false;
        }
        if (alias === (controller.selectedAdapter.alias || "")) {
            aliasDirty = false;
            return false;
        }
        if (!controller.adapterOperation("set-alias", { alias: alias }))
            return false;
        aliasDirty = false;
        return true;
    }

    function clearDiscoverableTimeoutDirty() { discoverableTimeoutDirty = false; }
    function clearPairableTimeoutDirty() { pairableTimeoutDirty = false; }
    function saveTimeoutIfDirty(dirty, operation, value, currentValue, clearDirty) {
        if (!dirty)
            return false;
        const timeout = Math.round(Number(value) || 0);
        if (timeout === Number(currentValue || 0)) {
            clearDirty();
            return false;
        }
        if (!controller.adapterOperation(operation, { timeout: timeout }))
            return false;
        clearDirty();
        return true;
    }

    function saveDirtyFields() {
        autoSaveTimer.stop();
        if (!hasDirtyFields || !controller.selectedAdapter.key)
            return;
        if (controller.globalRequestInFlight)
            return;
        if (saveAliasIfDirty())
            return;
        if (saveTimeoutIfDirty(discoverableTimeoutDirty, "set-discoverable-timeout",
                discoverableTimeoutRow.value, controller.selectedAdapter.discoverable_timeout,
                clearDiscoverableTimeoutDirty))
            return;
        saveTimeoutIfDirty(pairableTimeoutDirty, "set-pairable-timeout",
            pairableTimeoutRow.value, controller.selectedAdapter.pairable_timeout,
            clearPairableTimeoutDirty);
    }

    Component.onCompleted: Qt.callLater(function () { section.syncAdapterFields(true); })
    Component.onDestruction: section.saveDirtyFields()

    Timer {
        id: autoSaveTimer
        interval: 700
        repeat: false
        onTriggered: section.saveDirtyFields()
    }

    Connections {
        target: section.controller
        function onSelectedAdapterChanged() {
            section.syncAdapterFields(section.displayedAdapterKey !== (section.controller.selectedAdapter.key || ""));
        }
        function onActionInFlightChanged() {
            if (!section.controller.globalRequestInFlight && section.hasDirtyFields)
                autoSaveTimer.restart();
        }
    }

    Ui.DetailCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 235
        title: "Adapter"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm

            Ui.FieldLabel { text: "Selected adapter" }
            Ui.SegmentedControl {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                options: section.controller.adapters.map(function (adapter) {
                    return { value: adapter.key, label: adapter.alias || adapter.name || "Adapter" };
                })
                value: section.controller.selectedAdapter.key || ""
                interactive: !section.controller.globalRequestInFlight
                    && !section.hasDirtyFields
                    && section.controller.adapters.length > 0
                onSelected: function (value) { section.controller.setPreferredAdapter(value); }
            }

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Adapter powered"
                subtitle: "Power only this Bluetooth adapter"
                checked: !!section.controller.selectedAdapter.powered
                interactive: !!section.controller.selectedAdapter.key && !section.controller.globalRequestInFlight
                onClicked: section.controller.setAdapterPower(section.controller.selectedAdapter,
                    !section.controller.selectedAdapter.powered)
            }

            Ui.FieldLabel { text: "Adapter alias" }
            Ui.TextField {
                id: adapterAliasInput
                Layout.fillWidth: true
                text: ""
                maximumLength: 248
                inputValid: section.aliasValid
                readOnly: section.controller.globalRequestInFlight || !section.controller.selectedAdapter.key
                onEdited: section.queueAutoSave(section.markAliasDirty)
                onEditingFinished: section.saveDirtyFields()
                onAccepted: section.saveDirtyFields()
            }
        }
    }

    Ui.DetailCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 230
        title: "Visibility and pairing"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Discoverable"
                subtitle: "Allow nearby devices to find this computer"
                checked: !!section.controller.selectedAdapter.discoverable
                interactive: !!section.controller.selectedAdapter.key
                    && section.controller.selectedAdapter.powered
                    && !section.controller.globalRequestInFlight
                onClicked: section.controller.adapterOperation("set-discoverable", { discoverable: !section.controller.selectedAdapter.discoverable })
            }

            Ui.LabeledValueSlider {
                id: discoverableTimeoutRow
                Layout.fillWidth: true
                label: "Discoverable timeout"
                from: 0
                to: section.maximumTimeout
                stepSize: section.timeoutStep
                valueText: Ui.Format.duration(value)
                enabled: !section.controller.globalRequestInFlight && !!section.controller.selectedAdapter.key
                onEdited: function (dragging) { section.queueAutoSave(section.markDiscoverableTimeoutDirty, !dragging); }
                onEditingFinished: section.saveDirtyFields()
            }

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Incoming pairing"
                subtitle: "Allow new devices to request pairing"
                checked: !!section.controller.selectedAdapter.pairable
                interactive: !!section.controller.selectedAdapter.key && !section.controller.globalRequestInFlight
                onClicked: section.controller.adapterOperation("set-pairable", { pairable: !section.controller.selectedAdapter.pairable })
            }

            Ui.LabeledValueSlider {
                id: pairableTimeoutRow
                Layout.fillWidth: true
                label: "Pairable timeout"
                from: 0
                to: section.maximumTimeout
                stepSize: section.timeoutStep
                valueText: Ui.Format.duration(value)
                enabled: !section.controller.globalRequestInFlight && !!section.controller.selectedAdapter.key
                onEdited: function (dragging) { section.queueAutoSave(section.markPairableTimeoutDirty, !dragging); }
                onEditingFinished: section.saveDirtyFields()
            }
        }
    }

    Ui.DetailCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 245
        title: "Bluetooth behavior"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Trust after pairing"
                subtitle: "Mark successfully paired devices as trusted"
                checked: section.controller.trustAfterPair
                interactive: !section.controller.globalRequestInFlight
                onClicked: section.controller.setTrustAfterPair(!section.controller.trustAfterPair)
            }

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Reconnect after resume"
                subtitle: "Reconnect devices that were active before suspend"
                checked: section.controller.management.reconnect_on_resume !== false
                interactive: !section.controller.globalRequestInFlight
                onClicked: section.controller.updateManagement({ reconnect_on_resume: !checked })
            }

            Ui.FieldLabel { text: "State on login" }
            Ui.SegmentedControl {
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                options: [
                    { value: "remember", label: "Restore" },
                    { value: "enable", label: "Enable" },
                    { value: "disable", label: "Disable" }
                ]
                value: section.controller.management.launch_state || "remember"
                interactive: !section.controller.globalRequestInFlight
                onSelected: function (value) { section.controller.updateManagement({ launch_state: value }); }
            }
        }
    }

    Ui.DetailCard {
        Layout.fillWidth: true
        Layout.preferredHeight: 102
        title: "Device list"

        ColumnLayout {
            anchors.fill: parent
            spacing: Ui.Theme.spacingSm

            Ui.ToggleRow {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                title: "Keep recently found devices"
                subtitle: "Retain cached devices in Search all"
                checked: !!section.controller.management.show_recent_devices
                interactive: !section.controller.globalRequestInFlight
                onClicked: section.controller.updateManagement({ show_recent_devices: !checked })
            }
        }
    }
}
