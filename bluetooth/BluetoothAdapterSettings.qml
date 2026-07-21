import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus
        || discoverableTimeoutInput.inputActiveFocus
        || pairableTimeoutInput.inputActiveFocus
    property string displayedAdapterKey: ""
    readonly property bool aliasValid: adapterAliasInput.text.trim().length > 0
    readonly property bool discoverableTimeoutValid: validTimeout(discoverableTimeoutInput.text)
    readonly property bool pairableTimeoutValid: validTimeout(pairableTimeoutInput.text)

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

    function validTimeout(text) {
        const value = String(text).trim();
        if (!/^\d+$/.test(value))
            return false;
        const parsed = Number(value);
        return Number.isSafeInteger(parsed) && parsed >= 0 && parsed <= 4294967295;
    }

    function syncAdapterFields(force) {
        const adapter = controller.selectedAdapter || ({});
        const nextKey = adapter.key || "";
        if (!force && editing && nextKey === displayedAdapterKey)
            return;
        displayedAdapterKey = nextKey;
        adapterAliasInput.text = adapter.alias || "";
        discoverableTimeoutInput.text = String(adapter.discoverable_timeout || 0);
        pairableTimeoutInput.text = String(adapter.pairable_timeout || 0);
        console.info("shelllist bluetooth adapter fields synchronized adapter_key=" + nextKey);
    }

    function saveAlias() {
        const alias = adapterAliasInput.text.trim();
        if (!controller.selectedAdapter.key || !aliasValid) {
            console.warn("shelllist bluetooth adapter alias rejected adapter_key=" + (controller.selectedAdapter.key || "") + " reason=invalid-value");
            controller.status = "Enter a non-empty Bluetooth adapter alias.";
            return false;
        }
        return controller.adapterOperation("set-alias", { alias: alias });
    }

    function saveTimeout(operation, text, valid) {
        if (!controller.selectedAdapter.key || !valid) {
            console.warn("shelllist bluetooth adapter timeout rejected operation=" + operation
                + " adapter_key=" + (controller.selectedAdapter.key || "") + " value=" + text);
            controller.status = "Enter a whole-number Bluetooth timeout from 0 to 4294967295 seconds.";
            return false;
        }
        return controller.adapterOperation(operation, { timeout: Number(text) });
    }

    Component.onCompleted: Qt.callLater(function () { section.syncAdapterFields(true); })

    Connections {
        target: section.controller
        function onSelectedAdapterChanged() {
            section.syncAdapterFields(section.displayedAdapterKey !== (section.controller.selectedAdapter.key || ""));
        }
    }

    Ui.SegmentedControl {
        Layout.fillWidth: true
        Layout.preferredHeight: Ui.Theme.compactControlHeight
        options: section.controller.adapters.map(function (adapter) {
            return { value: adapter.key, label: adapter.alias || adapter.name || "Adapter" };
        })
        value: section.controller.selectedAdapter.key || ""
        interactive: !section.controller.actionInFlight && section.controller.adapters.length > 0
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
    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Ui.TextField {
            id: adapterAliasInput
            Layout.fillWidth: true
            text: ""
            maximumLength: 248
            inputValid: section.aliasValid
            readOnly: section.controller.actionInFlight
            onAccepted: section.saveAlias()
        }
        Ui.ActionButton {
            Layout.preferredWidth: 92
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save"
            tone: "accent"
            enabled: !section.controller.actionInFlight
                && adapterAliasInput.text.trim().length > 0
                && adapterAliasInput.text.trim() !== (section.controller.selectedAdapter.alias || "")
            onClicked: section.saveAlias()
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Ui.Theme.spacingMd
        rowSpacing: Ui.Theme.spacingSm

        Text { text: "Discoverable timeout"; color: Ui.Theme.mutedText; font.family: Ui.Theme.fontFamily; font.pixelSize: Ui.Theme.fontSizeBody }
        Ui.TextField {
            id: discoverableTimeoutInput
            Layout.fillWidth: true
            text: "0"
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 10
            inputValid: section.discoverableTimeoutValid
            readOnly: section.controller.actionInFlight
            onAccepted: section.saveTimeout("set-discoverable-timeout", text, section.discoverableTimeoutValid)
        }

        Text { text: "Pairable timeout"; color: Ui.Theme.mutedText; font.family: Ui.Theme.fontFamily; font.pixelSize: Ui.Theme.fontSizeBody }
        Ui.TextField {
            id: pairableTimeoutInput
            Layout.fillWidth: true
            text: "0"
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 10
            inputValid: section.pairableTimeoutValid
            readOnly: section.controller.actionInFlight
            onAccepted: section.saveTimeout("set-pairable-timeout", text, section.pairableTimeoutValid)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Item { Layout.fillWidth: true }
        Ui.ActionButton {
            Layout.preferredWidth: 148
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save discoverable"
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
                && section.discoverableTimeoutValid
                && Number(discoverableTimeoutInput.text) !== Number(section.controller.selectedAdapter.discoverable_timeout || 0)
            onClicked: section.saveTimeout("set-discoverable-timeout", discoverableTimeoutInput.text, section.discoverableTimeoutValid)
        }
        Ui.ActionButton {
            Layout.preferredWidth: 132
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save pairable"
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
                && section.pairableTimeoutValid
                && Number(pairableTimeoutInput.text) !== Number(section.controller.selectedAdapter.pairable_timeout || 0)
            onClicked: section.saveTimeout("set-pairable-timeout", pairableTimeoutInput.text, section.pairableTimeoutValid)
        }
    }
}
