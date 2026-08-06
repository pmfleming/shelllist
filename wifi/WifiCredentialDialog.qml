pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

ModalFrame {
    id: dialog

    required property WifiPromptController prompt
    signal accepted(var values)
    signal cancelled

    title: prompt.credentialTitle
    detail: prompt.credentialDetail
    maximumCardWidth: 620

    Keys.onEscapePressed: dialog.cancelled()

    Flickable {
        width: parent.width
        height: Math.min(360, fieldsColumn.implicitHeight)
        contentHeight: fieldsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: fieldsColumn
            width: parent.width
            spacing: Theme.spacingMd

            Repeater {
                model: dialog.prompt.credentialFields

                delegate: Column {
                    id: fieldColumn
                    required property var modelData
                    width: fieldsColumn.width
                    spacing: Theme.spacingXs

                    FieldLabel {
                        width: parent.width
                        height: 16
                        text: fieldColumn.modelData.label + (fieldColumn.modelData.required ? " *" : "")
                    }

                    TextField {
                        width: parent.width
                        height: Theme.controlHeight
                        text: String(dialog.prompt.credentialValues[fieldColumn.modelData.key] || "")
                        password: !!fieldColumn.modelData.password
                        placeholder: fieldColumn.modelData.required ? "Required" : "Optional"
                        onEdited: function (value) {
                            const values = Object.assign({}, dialog.prompt.credentialValues);
                            values[fieldColumn.modelData.key] = value;
                            dialog.prompt.credentialValues = values;
                        }
                    }
                }
            }
        }
    }

    ToggleRow {
        width: parent.width
        height: Theme.controlHeight
        visible: dialog.prompt.credentialMode === "daemon-secret" && dialog.prompt.saveSecretSupported
        title: "Save in the desktop keyring"
        showSubtitle: false
        checked: dialog.prompt.saveSecret
        onClicked: dialog.prompt.saveSecret = !dialog.prompt.saveSecret
    }

    RowLayout {
        width: parent.width
        spacing: Theme.spacingMd

        ActionButton {
            Layout.fillWidth: true
            label: "Cancel"
            onClicked: dialog.cancelled()
        }

        ActionButton {
            Layout.fillWidth: true
            label: dialog.prompt.credentialMode === "daemon-secret" ? "Provide" : "Connect"
            tone: "accent"
            onClicked: dialog.accepted(dialog.prompt.credentialValues)
        }
    }
}
