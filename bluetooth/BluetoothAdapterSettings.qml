import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus || discoverableTimeoutRow.inputActiveFocus || pairableTimeoutRow.inputActiveFocus
    property string displayedAdapterKey: ""
    readonly property var draft: controller.adapterEdits.draft(displayedAdapterKey)
    readonly property var dirtyFields: ({
        alias: draft.fields.alias !== undefined,
        discoverableTimeout: draft.fields.discoverableTimeout !== undefined,
        pairableTimeout: draft.fields.pairableTimeout !== undefined
    })
    readonly property bool hasDirtyFields: dirtyFields.alias || dirtyFields.discoverableTimeout || dirtyFields.pairableTimeout
    readonly property bool aliasValid: adapterAliasInput.text.trim().length > 0

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

    function setDirty(field: string, value: bool): void {
        if (value === false) {
            controller.adapterEdits.clearField(displayedAdapterKey, field);
            return;
        }
        const values = {alias: adapterAliasInput.text, discoverableTimeout: discoverableTimeoutRow.value, pairableTimeout: pairableTimeoutRow.value};
        controller.adapterEdits.edit(displayedAdapterKey, field, values[field]);
    }
    function syncAdapterFields(force: bool): void {
        const adapter = controller.selectedAdapter;
        const nextKey = adapter.key || "";
        if (nextKey !== displayedAdapterKey)
            autoSaveTimer.stop();
        displayedAdapterKey = nextKey;
        const fields = controller.adapterEdits.draft(nextKey).fields;
        adapterAliasInput.text = fields.alias !== undefined ? fields.alias : (adapter.alias || "");
        discoverableTimeoutRow.value = fields.discoverableTimeout ?? Math.min(3600, Number(adapter.discoverable_timeout || 0));
        pairableTimeoutRow.value = fields.pairableTimeout ?? Math.min(3600, Number(adapter.pairable_timeout || 0));
    }

    function queueAutoSave(field: string, debounce: var): void {
        setDirty(field, true);
        controller.status = "Bluetooth adapter changes pending…";
        debounce === false ? autoSaveTimer.stop() : autoSaveTimer.restart();
    }

    function saveDirtyFields(): void {
        autoSaveTimer.stop();
        controller.adapterEdits.saveNext(displayedAdapterKey);
    }

    Component.onCompleted: Qt.callLater(section.syncAdapterFields, true)
    onDraftChanged: Qt.callLater(section.syncAdapterFields, false)
    Component.onDestruction: if (hasDirtyFields && !draft.pendingField && !draft.error)
        section.saveDirtyFields()

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
            if (!section.controller.globalRequestInFlight && section.hasDirtyFields && !section.draft.error)
                autoSaveTimer.restart();
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        Layout.preferredHeight: visible ? implicitHeight : 0
        visible: section.draft.error.length > 0
        title: qsTr("Unsaved adapter settings")
        Ui.ThemeText {
            Layout.fillWidth: true
            text: section.draft.error
            color: Ui.Theme.danger
            wrapMode: Text.WordWrap
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.ActionButton {
                objectName: "retryAdapterSettings"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: qsTr("Retry save")
                enabled: !section.controller.globalRequestInFlight
                onClicked: section.controller.adapterEdits.retry(section.displayedAdapterKey)
            }
            Ui.ActionButton {
                objectName: "discardAdapterSettings"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                label: qsTr("Discard drafts")
                enabled: !section.draft.pendingField
                onClicked: section.controller.adapterEdits.discard(section.displayedAdapterKey)
            }
        }
    }

    Ui.DetailColumnCard {
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        title: qsTr("Bluetooth radio")

        Ui.FieldLabel {
            visible: section.controller.adapters.length > 1
            text: qsTr("Preferred radio")
        }
        Ui.SegmentedControl {
            objectName: "bluetoothRadioSelector"
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
            objectName: "bluetoothRadioPower"
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            title: qsTr("Radio power")
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
            objectName: "adapterNameInput"
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
