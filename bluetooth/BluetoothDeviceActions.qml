pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: section

    required property BluetoothController controller
    readonly property bool editingName: renameInput.inputActiveFocus

    Layout.fillWidth: true
    spacing: Ui.Theme.spacingMd

    Connections {
        target: section.controller
        function onSelectedResultChanged() { renameInput.text = section.controller.selectedDevice.name || ""; }
    }

    Text {
        text: "Device name"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeBody
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm

        Ui.TextField {
            id: renameInput
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            text: section.controller.selectedDevice.name || ""
            maximumLength: 248
            readOnly: section.controller.actionInFlight
            onAccepted: section.controller.renameSelected(text)
        }
        Ui.ActionButton {
            Layout.preferredWidth: 92
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            label: "Save"
            tone: "accent"
            enabled: !!(section.controller.selectedDevice.capabilities && section.controller.selectedDevice.capabilities.can_rename)
                && renameInput.text.trim().length > 0
                && renameInput.text.trim() !== (section.controller.selectedDevice.name || "")
                && !section.controller.actionInFlight
            onClicked: section.controller.renameSelected(renameInput.text)
        }
    }

    Repeater {
        model: section.controller.detailActions.filter(function (action) {
            return action.visible !== false && (action.presentation || {}).group === "settings";
        })

        delegate: Ui.ToggleRow {
            required property var modelData

            Layout.fillWidth: true
            Layout.preferredHeight: 36
            title: modelData.label
            hotkey: modelData.shortcut || ""
            checked: !!(modelData.state && modelData.state.checked)
            tone: (modelData.presentation || {}).tone || "normal"
            interactive: modelData.enabled !== false
            showSubtitle: false
            onClicked: section.controller.triggerDetailAction(modelData.id)
        }
    }
}
