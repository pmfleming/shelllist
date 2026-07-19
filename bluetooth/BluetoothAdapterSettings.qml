pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section
    required property BluetoothController controller
    Layout.fillWidth: true
    spacing: 10
    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Ui.Theme.border }
    Text { text: "Adapter settings"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 14; font.bold: true }
    Repeater {
        model: section.controller.adapters
        delegate: BluetoothActionButton {
            required property var modelData
            label: (modelData.key === section.controller.selectedAdapter.key ? "✓  " : "") + (modelData.alias || modelData.name)
            onClicked: section.controller.preferredAdapterKey = modelData.key
        }
    }
    BluetoothDetailValue { label: "Controller"; value: section.controller.selectedAdapter.name || "" }
    Text { text: "Adapter alias"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 38
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surfaceRaised
        border.color: adapterAliasInput.activeFocus ? Ui.Theme.accent : Ui.Theme.border
        TextInput {
            id: adapterAliasInput
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: section.controller.selectedAdapter.alias || ""
            maximumLength: 248
            verticalAlignment: TextInput.AlignVCenter
            color: Ui.Theme.text
            selectionColor: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 13
            onAccepted: section.controller.adapterOperation("set-alias", { alias: text.trim() })
        }
    }
    BluetoothActionButton { label: "Save adapter alias"; available: adapterAliasInput.text.trim().length > 0 && adapterAliasInput.text.trim() !== (section.controller.selectedAdapter.alias || ""); onClicked: section.controller.adapterOperation("set-alias", { alias: adapterAliasInput.text.trim() }) }
    BluetoothActionButton { label: section.controller.selectedAdapter.discoverable ? "Disable discoverable" : "Enable discoverable"; available: !!section.controller.selectedAdapter.key && section.controller.selectedAdapter.powered; onClicked: section.controller.adapterOperation("set-discoverable", { discoverable: !section.controller.selectedAdapter.discoverable }) }
    BluetoothActionButton { label: section.controller.selectedAdapter.pairable ? "Disable incoming pairing" : "Enable incoming pairing"; available: !!section.controller.selectedAdapter.key; onClicked: section.controller.adapterOperation("set-pairable", { pairable: !section.controller.selectedAdapter.pairable }) }
    BluetoothActionButton { label: (section.controller.trustAfterPair ? "✓  " : "") + "Trust after pairing"; onClicked: section.controller.trustAfterPair = !section.controller.trustAfterPair }
    Text { text: "Discoverable timeout (seconds)"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Ui.Theme.cardRadius; color: Ui.Theme.surfaceRaised; border.color: Ui.Theme.border
        TextInput { id: discoverableTimeoutInput; anchors.fill: parent; anchors.margins: 10; text: String(section.controller.selectedAdapter.discoverable_timeout || 0); inputMethodHints: Qt.ImhDigitsOnly; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; verticalAlignment: TextInput.AlignVCenter; onAccepted: section.controller.adapterOperation("set-discoverable-timeout", { timeout: Number(text) }) }
    }
    BluetoothActionButton { label: "Save discoverable timeout"; onClicked: section.controller.adapterOperation("set-discoverable-timeout", { timeout: Number(discoverableTimeoutInput.text) }) }
    Text { text: "Pairable timeout (seconds)"; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 36; radius: Ui.Theme.cardRadius; color: Ui.Theme.surfaceRaised; border.color: Ui.Theme.border
        TextInput { id: pairableTimeoutInput; anchors.fill: parent; anchors.margins: 10; text: String(section.controller.selectedAdapter.pairable_timeout || 0); inputMethodHints: Qt.ImhDigitsOnly; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; verticalAlignment: TextInput.AlignVCenter; onAccepted: section.controller.adapterOperation("set-pairable-timeout", { timeout: Number(text) }) }
    }
    BluetoothActionButton { label: "Save pairable timeout"; onClicked: section.controller.adapterOperation("set-pairable-timeout", { timeout: Number(pairableTimeoutInput.text) }) }
    BluetoothDetailValue { label: "Adapter modalias"; value: section.controller.selectedAdapter.modalias || "" }
    Text { Layout.fillWidth: true; text: section.controller.canCancelTransfer ? "Esc: cancel file transfer" : (section.controller.canCancelOperation ? "Esc: cancel operation" : "Enter: primary action   Left: close details   Esc: close"); color: Ui.Theme.mutedText; font.family: Ui.Theme.fontFamily; font.pixelSize: 10; wrapMode: Text.WordWrap }
}
