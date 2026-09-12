import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus || discoverableTimeoutRow.inputActiveFocus || pairableTimeoutRow.inputActiveFocus
    property string displayedAdapterKey: ""
    property var dirtyFields: ({
            alias: false,
            discoverableTimeout: false,
            pairableTimeout: false
        })
    readonly property bool hasDirtyFields: dirtyFields.alias || dirtyFields.discoverableTimeout || dirtyFields.pairableTimeout
    readonly property bool aliasValid: adapterAliasInput.text.trim().length > 0

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

    function setDirty(field: string, value: bool): void {
        const next = Object.assign({}, dirtyFields);
        next[field] = value !== false;
        dirtyFields = next;
    }
    function clearDirtyFields(): void {
        dirtyFields = ({
                alias: false,
                discoverableTimeout: false,
                pairableTimeout: false
            });
    }

    function syncAlias(force: bool, adapter: var): void {
        if (force || !dirtyFields.alias)
            adapterAliasInput.text = adapter.alias || "";
    }
    function syncTimeout(force: bool, field: string, control: var, value: var): void {
        if (force || !dirtyFields[field])
            control.value = Math.min(3600, Number(value || 0));
    }
    function syncAdapterFields(force: bool): void {
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
        syncTimeout(syncAll, "discoverableTimeout", discoverableTimeoutRow, adapter.discoverable_timeout);
        syncTimeout(syncAll, "pairableTimeout", pairableTimeoutRow, adapter.pairable_timeout);
    }

    function queueAutoSave(field: string, debounce: var): void {
        setDirty(field, true);
        controller.status = "Bluetooth adapter changes pending…";
        debounce === false ? autoSaveTimer.stop() : autoSaveTimer.restart();
    }

    function saveAliasIfDirty(): bool {
        if (!dirtyFields.alias)
            return false;
        const alias = adapterAliasInput.text.trim();
        if (!aliasValid) {
            controller.status = "Enter a non-empty Bluetooth adapter alias.";
            return false;
        }
        if (alias === (controller.selectedAdapter.alias || "")) {
            setDirty("alias", false);
            return false;
        }
        if (!controller.adapterOperation("set-alias", {
            alias: alias
        }))
            return false;
        setDirty("alias", false);
        return true;
    }

    function saveTimeoutIfDirty(field: string, operation: string, value: real, currentValue: var): bool {
        if (!dirtyFields[field])
            return false;
        const timeout = Math.round(Number(value) || 0);
        if (timeout === Number(currentValue || 0)) {
            setDirty(field, false);
            return false;
        }
        if (!controller.adapterOperation(operation, {
            timeout: timeout
        }))
            return false;
        setDirty(field, false);
        return true;
    }

    function saveDirtyFields(): void {
        autoSaveTimer.stop();
        if (!hasDirtyFields || !controller.selectedAdapter.key)
            return;
        if (controller.globalRequestInFlight)
            return;
        if (saveAliasIfDirty())
            return;
        if (saveTimeoutIfDirty("discoverableTimeout", "set-discoverable-timeout", discoverableTimeoutRow.value, controller.selectedAdapter.discoverable_timeout))
            return;
        saveTimeoutIfDirty("pairableTimeout", "set-pairable-timeout", pairableTimeoutRow.value, controller.selectedAdapter.pairable_timeout);
    }

    Component.onCompleted: Qt.callLater(section.syncAdapterFields, true)
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

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        title: qsTr("Adapter")

        Ui.FieldLabel {
            visible: section.controller.adapters.length > 1
            text: qsTr("Selected adapter")
        }
        Ui.SegmentedControl {
            visible: section.controller.adapters.length > 1
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: section.controller.adapters.map(function (adapter) {
                return {
                    value: adapter.key,
                    label: adapter.alias || adapter.name || "Adapter"
                };
            })
            value: section.controller.selectedAdapter.key || ""
            interactive: !section.controller.globalRequestInFlight && !section.hasDirtyFields && section.controller.adapters.length > 0
            onSelected: function (value) {
                section.controller.setPreferredAdapter(value);
            }
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            title: qsTr("Adapter power")
            subtitle: section.controller.radio.hard_blocked ? "Hardware blocked"
                : section.controller.radio.soft_blocked ? "Software blocked"
                : section.controller.selectedAdapter.powered ? "On · selected adapter" : "Off · selected adapter"
            checked: !!section.controller.selectedAdapter.powered
            interactive: !!section.controller.selectedAdapter.key && !section.controller.globalRequestInFlight && !section.controller.radio.hard_blocked
            onClicked: section.controller.setAdapterPower(section.controller.selectedAdapter, !section.controller.selectedAdapter.powered)
        }

        Ui.FieldLabel {
            text: qsTr("Computer’s Bluetooth name")
        }
        Ui.TextField {
            id: adapterAliasInput
            Layout.fillWidth: true
            text: ""
            maximumLength: 248
            inputValid: section.aliasValid
            readOnly: section.controller.globalRequestInFlight || !section.controller.selectedAdapter.key
            onEdited: section.queueAutoSave("alias")
            onEditingFinished: section.saveDirtyFields()
            onAccepted: section.saveDirtyFields()
        }

        Ui.FieldLabel { text: qsTr("Bluetooth state on login") }
        Ui.SegmentedControl {
            objectName: "bluetoothLoginState"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: [
                {value: "remember", label: "Restore"},
                {value: "enable", label: "Enable"},
                {value: "disable", label: "Disable"}
            ]
            value: section.controller.management.launch_state || "remember"
            interactive: !section.controller.globalRequestInFlight
            onSelected: function (value) {
                section.controller.updateManagement({launch_state: value});
            }
        }

        Ui.DisclosureSection {
            objectName: "adapterTechnicalDetails"
            Layout.fillWidth: true
            title: qsTr("Technical details")
            Ui.DetailField {
                Layout.fillWidth: true
                label: qsTr("Controller")
                value: section.controller.selectedAdapter.name || "Unavailable"
            }
            Ui.DetailField {
                Layout.fillWidth: true
                label: qsTr("Address")
                value: section.controller.selectedAdapter.address || "Unavailable"
            }
            Ui.DetailField {
                Layout.fillWidth: true
                label: qsTr("Modalias")
                value: section.controller.selectedAdapter.modalias || "Unavailable"
            }
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        title: qsTr("Visibility and pairing")

        BluetoothAdapterAccessControl {
            id: discoverableTimeoutRow
            Layout.fillWidth: true
            controller: section.controller
            mode: "discoverable"
            onEdited: function (dragging) {
                section.queueAutoSave("discoverableTimeout", !dragging);
            }
            onEditingFinished: section.saveDirtyFields()
        }

        BluetoothAdapterAccessControl {
            id: pairableTimeoutRow
            Layout.fillWidth: true
            controller: section.controller
            mode: "pairable"
            onEdited: function (dragging) {
                section.queueAutoSave("pairableTimeout", !dragging);
            }
            onEditingFinished: section.saveDirtyFields()
        }

        Ui.ToggleRow {
            objectName: "defaultTrustAfterPairing"
            Layout.fillWidth: true
            title: qsTr("Automatically trust new devices")
            subtitle: qsTr("Default after successful pairing")
            checked: section.controller.trustAfterPair
            interactive: !section.controller.globalRequestInFlight
            onClicked: section.controller.setTrustAfterPair(!checked)
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        title: qsTr("Connection defaults")

        Ui.ToggleRow {
            objectName: "defaultReconnectAfterWake"
            Layout.fillWidth: true
            title: qsTr("Reconnect after wake")
            subtitle: qsTr("Devices active before sleep")
            checked: section.controller.management.reconnect_on_resume !== false
            interactive: !section.controller.globalRequestInFlight
            onClicked: section.controller.updateManagement({reconnect_on_resume: !checked})
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Pairing and connection defaults apply unless overridden under Device → Advanced device options.")
            wrapMode: Text.WordWrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }
}
