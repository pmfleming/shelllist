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

    ThemeText {
        visible: dialog.prompt.credentialFields.some(field => !!field.required)
        text: qsTr("* Required")
        font.pixelSize: Theme.formSupportSize
        color: Theme.mutedText
    }

    Flickable {
        width: parent.width
        height: Math.min(dialog.compact ? 260 : 360, fieldsColumn.implicitHeight)
        contentHeight: fieldsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: fieldsColumn
            width: parent.width
            spacing: dialog.bodySpacing

            Repeater {
                model: dialog.prompt.credentialFields

                delegate: FormField {
                    id: fieldColumn
                    required property var modelData
                    width: fieldsColumn.width
                    label: modelData.label
                    requiredInput: !!modelData.required

                    TextField {
                        Layout.fillWidth: true
                        text: String(dialog.prompt.credentialValues[fieldColumn.modelData.key] || "")
                        password: !!fieldColumn.modelData.password
                        placeholder: fieldColumn.modelData.required ? "" : qsTr("Optional")
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
        title: qsTr("Save in the desktop keyring")
        showSubtitle: false
        checked: dialog.prompt.saveSecret
        onClicked: dialog.prompt.saveSecret = !dialog.prompt.saveSecret
    }

    icon: "wifi"
    actions: [
        {id: "accept", label: prompt.credentialMode === "daemon-secret" ? qsTr("Provide credentials") : qsTr("Connect"), icon: "wifi", presentation: {group: "primary"}},
        {id: "cancel", label: qsTr("Cancel"), icon: "close", presentation: {group: "toolbar"}}
    ]
    onActionTriggered: function(actionId) {
        if (actionId === "cancel") cancelled();
        else accepted(prompt.credentialValues);
    }
}
