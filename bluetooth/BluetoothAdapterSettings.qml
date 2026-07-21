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

    function syncAdapterFields(force) {
        const adapter = controller.selectedAdapter || ({});
        const nextKey = adapter.key || "";
        const adapterChanged = nextKey !== displayedAdapterKey;
        if (adapterChanged) {
            autoSaveTimer.stop();
            clearDirtyFields();
        }
        displayedAdapterKey = nextKey;
        if (force || adapterChanged || !aliasDirty)
            adapterAliasInput.text = adapter.alias || "";
        if (force || adapterChanged || !discoverableTimeoutDirty)
            discoverableTimeoutSlider.value = Math.min(maximumTimeout, Number(adapter.discoverable_timeout || 0));
        if (force || adapterChanged || !pairableTimeoutDirty)
            pairableTimeoutSlider.value = Math.min(maximumTimeout, Number(adapter.pairable_timeout || 0));
        console.info("shelllist bluetooth adapter fields synchronized adapter_key=" + nextKey
            + " pending=" + hasDirtyFields);
    }

    function queueAutoSave(field, debounce) {
        if (field === "alias")
            aliasDirty = true;
        else if (field === "discoverable-timeout")
            discoverableTimeoutDirty = true;
        else if (field === "pairable-timeout")
            pairableTimeoutDirty = true;
        controller.status = "Bluetooth adapter changes pending…";
        if (debounce === false)
            autoSaveTimer.stop();
        else
            autoSaveTimer.restart();
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

    function saveTimeoutIfDirty(field, operation, value, currentValue) {
        const dirty = field === "discoverable-timeout" ? discoverableTimeoutDirty : pairableTimeoutDirty;
        if (!dirty)
            return false;
        value = Math.round(Number(value) || 0);
        if (value === Number(currentValue || 0)) {
            if (field === "discoverable-timeout")
                discoverableTimeoutDirty = false;
            else
                pairableTimeoutDirty = false;
            return false;
        }
        if (!controller.adapterOperation(operation, { timeout: value }))
            return false;
        if (field === "discoverable-timeout")
            discoverableTimeoutDirty = false;
        else
            pairableTimeoutDirty = false;
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
        if (saveTimeoutIfDirty("discoverable-timeout", "set-discoverable-timeout",
                discoverableTimeoutSlider.value, controller.selectedAdapter.discoverable_timeout))
            return;
        saveTimeoutIfDirty("pairable-timeout", "set-pairable-timeout",
            pairableTimeoutSlider.value, controller.selectedAdapter.pairable_timeout);
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

    Text {
        text: "Adapter alias"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }
    Ui.TextField {
        id: adapterAliasInput
        Layout.fillWidth: true
        text: ""
        maximumLength: 248
        inputValid: section.aliasValid
        readOnly: section.controller.actionInFlight
        onEdited: section.queueAutoSave("alias")
        onEditingFinished: section.saveDirtyFields()
        onAccepted: section.saveDirtyFields()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        columnSpacing: Ui.Theme.spacingMd
        rowSpacing: Ui.Theme.spacingSm

        Text {
            text: "Discoverable timeout"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }
        Ui.ValueSlider {
            id: discoverableTimeoutSlider
            Layout.fillWidth: true
            from: 0
            to: section.maximumTimeout
            stepSize: section.timeoutStep
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
            onEdited: section.queueAutoSave("discoverable-timeout", !discoverableTimeoutSlider.pressed)
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

        Text {
            text: "Pairable timeout"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }
        Ui.ValueSlider {
            id: pairableTimeoutSlider
            Layout.fillWidth: true
            from: 0
            to: section.maximumTimeout
            stepSize: section.timeoutStep
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
            onEdited: section.queueAutoSave("pairable-timeout", !pairableTimeoutSlider.pressed)
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
