import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editing: adapterAliasInput.inputActiveFocus
        || discoverableTimeoutInput.inputActiveFocus
        || pairableTimeoutInput.inputActiveFocus

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

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
            text: section.controller.selectedAdapter.alias || ""
            maximumLength: 248
            readOnly: section.controller.actionInFlight
            onAccepted: section.controller.adapterOperation("set-alias", { alias: text.trim() })
        }
        Ui.ActionButton {
            Layout.preferredWidth: 92
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save"
            tone: "accent"
            enabled: !section.controller.actionInFlight
                && adapterAliasInput.text.trim().length > 0
                && adapterAliasInput.text.trim() !== (section.controller.selectedAdapter.alias || "")
            onClicked: section.controller.adapterOperation("set-alias", { alias: adapterAliasInput.text.trim() })
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
            text: String(section.controller.selectedAdapter.discoverable_timeout || 0)
            inputMethodHints: Qt.ImhDigitsOnly
            readOnly: section.controller.actionInFlight
            onAccepted: section.controller.adapterOperation("set-discoverable-timeout", { timeout: Number(text) })
        }

        Text { text: "Pairable timeout"; color: Ui.Theme.mutedText; font.family: Ui.Theme.fontFamily; font.pixelSize: Ui.Theme.fontSizeBody }
        Ui.TextField {
            id: pairableTimeoutInput
            Layout.fillWidth: true
            text: String(section.controller.selectedAdapter.pairable_timeout || 0)
            inputMethodHints: Qt.ImhDigitsOnly
            readOnly: section.controller.actionInFlight
            onAccepted: section.controller.adapterOperation("set-pairable-timeout", { timeout: Number(text) })
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
            onClicked: section.controller.adapterOperation("set-discoverable-timeout", { timeout: Number(discoverableTimeoutInput.text) })
        }
        Ui.ActionButton {
            Layout.preferredWidth: 132
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save pairable"
            enabled: !section.controller.actionInFlight && !!section.controller.selectedAdapter.key
            onClicked: section.controller.adapterOperation("set-pairable-timeout", { timeout: Number(pairableTimeoutInput.text) })
        }
    }
}
