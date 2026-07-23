import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus
        || discoverableTimeoutSlider.activeFocus
        || pairableTimeoutSlider.activeFocus
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

    function timeoutLabel(value) {
        const seconds = Math.round(Number(value) || 0);
        if (seconds === 0)
            return "No timeout";
        if (seconds < 60)
            return seconds + " sec";
        if (seconds % 60 === 0)
            return (seconds / 60) + " min";
        return Math.floor(seconds / 60) + "m " + (seconds % 60) + "s";
    }

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
            discoverableTimeoutSlider.value = Math.min(maximumTimeout, Number(adapter.discoverable_timeout || 0));
    }
    function syncPairableTimeout(force, adapter) {
        if (force || !pairableTimeoutDirty)
            pairableTimeoutSlider.value = Math.min(maximumTimeout, Number(adapter.pairable_timeout || 0));
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
        if (controller.actionInFlight)
            return;
        if (saveAliasIfDirty())
            return;
        if (saveTimeoutIfDirty(discoverableTimeoutDirty, "set-discoverable-timeout",
                discoverableTimeoutSlider.value, controller.selectedAdapter.discoverable_timeout,
                clearDiscoverableTimeoutDirty))
            return;
        saveTimeoutIfDirty(pairableTimeoutDirty, "set-pairable-timeout",
            pairableTimeoutSlider.value, controller.selectedAdapter.pairable_timeout,
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
            if (!section.controller.actionInFlight && section.hasDirtyFields)
                autoSaveTimer.restart();
        }
    }

    Ui.SegmentedControl {
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        options: section.controller.adapters.map(function (adapter) {
            return { value: adapter.key, label: adapter.alias || adapter.name || "Adapter" };
        })
        value: section.controller.selectedAdapter.key || ""
        interactive: !section.controller.actionInFlight
            && !section.hasDirtyFields
            && section.controller.adapters.length > 0
        onSelected: function (value) { section.controller.preferredAdapterKey = value; }
    }

    Ui.ToggleRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        title: "Discoverable"
        subtitle: "Allow nearby devices to find this computer"
        checked: !!section.controller.selectedAdapter.discoverable
        interactive: !!section.controller.selectedAdapter.key
            && section.controller.selectedAdapter.powered
            && !section.controller.actionInFlight
        onClicked: section.controller.adapterOperation("set-discoverable", { discoverable: !section.controller.selectedAdapter.discoverable })
    }

    Ui.ToggleRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        title: "Incoming pairing"
        subtitle: "Allow new devices to request pairing"
        checked: !!section.controller.selectedAdapter.pairable
        interactive: !!section.controller.selectedAdapter.key && !section.controller.actionInFlight
        onClicked: section.controller.adapterOperation("set-pairable", { pairable: !section.controller.selectedAdapter.pairable })
    }

    Ui.ToggleRow {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        title: "Trust after pairing"
        subtitle: "Mark successfully paired devices as trusted"
        checked: section.controller.trustAfterPair
        interactive: !section.controller.actionInFlight
        onClicked: section.controller.trustAfterPair = !section.controller.trustAfterPair
    }

    Ui.FieldLabel { text: "Adapter alias" }
    Ui.TextField {
        id: adapterAliasInput
        Layout.fillWidth: true
        text: ""
        maximumLength: 248
        inputValid: section.aliasValid
        readOnly: section.controller.actionInFlight
        onEdited: section.queueAutoSave(section.markAliasDirty)
        onEditingFinished: section.saveDirtyFields()
        onAccepted: section.saveDirtyFields()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Ui.Theme.spacingMd
        rowSpacing: Ui.Theme.spacingSm

        Ui.FieldLabel { text: "Discoverable timeout" }
        Ui.ValueSlider {
            id: discoverableTimeoutSlider
            Layout.fillWidth: true
            from: 0
            to: section.maximumTimeout
            stepSize: section.timeoutStep
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
            onEdited: section.queueAutoSave(section.markDiscoverableTimeoutDirty, !discoverableTimeoutSlider.pressed)
            onPressedChanged: if (!discoverableTimeoutSlider.pressed) section.saveDirtyFields()
        }
        Text {
            Layout.preferredWidth: 76
            text: section.timeoutLabel(discoverableTimeoutSlider.value)
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            horizontalAlignment: Text.AlignRight
        }

        Ui.FieldLabel { text: "Pairable timeout" }
        Ui.ValueSlider {
            id: pairableTimeoutSlider
            Layout.fillWidth: true
            from: 0
            to: section.maximumTimeout
            stepSize: section.timeoutStep
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
            onEdited: section.queueAutoSave(section.markPairableTimeoutDirty, !pairableTimeoutSlider.pressed)
            onPressedChanged: if (!pairableTimeoutSlider.pressed) section.saveDirtyFields()
        }
        Text {
            Layout.preferredWidth: 76
            text: section.timeoutLabel(pairableTimeoutSlider.value)
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            horizontalAlignment: Text.AlignRight
        }
    }
}
