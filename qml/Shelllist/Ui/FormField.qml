import QtQuick
import QtQuick.Layouts

// Passive composition. The single native editor remains the navigation target;
// labels and status never own values, focus, transactions or backend requests.
ColumnLayout {
    id: field
    default property alias content: editorHost.data
    property Item editor: editorHost.children.length > 0 ? editorHost.children[0] : null
    property string label: ""
    property bool requiredInput: false
    property bool reserveSupportingSpace: false
    property string supportingText: (editor as TextField)?.supportingText || (editor as TextEditor)?.supportingText || (editor as DropDownList)?.supportingText || ""
    property string errorText: (editor as TextField)?.errorText || (editor as TextEditor)?.errorText || (editor as DropDownList)?.errorText || ""
    property string statusText: ""
    readonly property string message: errorText || statusText || supportingText
    spacing: 0

    ThemeText {
        objectName: "formFieldLabel"
        Layout.fillWidth: true
        Layout.bottomMargin: visible ? Theme.spacingSm : 0
        visible: field.label.length > 0
        text: field.requiredInput ? qsTr("%1 (required)").arg(field.label) : field.label
        font.pixelSize: Theme.formLabelSize
        font.weight: Theme.fontWeightMedium
        color: Theme.mutedText
        wrapMode: Text.Wrap
    }
    ColumnLayout {
        id: editorHost
        Layout.fillWidth: true
        spacing: 0
    }
    ThemeText {
        objectName: "formFieldSupport"
        Layout.fillWidth: true
        Layout.topMargin: visible ? Theme.spacingXs : 0
        Layout.minimumHeight: field.reserveSupportingSpace ? 20 : 0
        visible: field.reserveSupportingSpace || field.message.length > 0
        text: field.message
        font.pixelSize: Theme.formSupportSize
        color: field.errorText.length > 0 ? Theme.danger : Theme.mutedText
        wrapMode: Text.Wrap
    }
    Binding {
        target: field.editor
        property: "Accessible.name"
        value: field.label
        when: field.editor !== null && field.label.length > 0
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: field.editor
        property: "Accessible.description"
        value: [field.requiredInput ? qsTr("Required") : "", field.message].filter(part => part.length > 0).join(". ")
        when: field.editor !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
