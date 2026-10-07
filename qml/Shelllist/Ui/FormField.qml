import QtQuick
import QtQuick.Layouts

// Passive value row (proposal C). The native editor remains the sole field
// identity; labels, badges, separators and commands never own transactions.
Item {
    id: field
    default property alias content: editorHost.data
    property Item editor: editorHost.children.length > 0 ? editorHost.children[0] : null
    property string label: ""
    property string icon: "text_fields"
    property string accessibleName: label
    property bool requiredInput: false
    property string supportingText: (editor as TextField)?.supportingText || (editor as TextEditor)?.supportingText || (editor as DropDownList)?.supportingText || ""
    property string errorText: (editor as TextField)?.errorText || (editor as TextEditor)?.errorText || (editor as DropDownList)?.errorText || ""
    property string statusText: ""
    // Reasons and ordinary guidance are available explicitly, never on hover.
    property string readOnlyReason: ""
    property bool helpOpen: false
    property bool showHelpButton: helpText.length > 0
    property bool copyAvailable: false
    property bool copyEnabled: true
    signal copyRequested
    readonly property bool editorAvailable: ((editor as TextField)?.editSession || (editor as TextEditor)?.editSession || (editor as DropDownList)?.editSession)?.available ?? false
    readonly property string helpText: [readOnlyReason, supportingText].filter(Boolean).join(". ")
    readonly property string message: errorText || statusText || (helpOpen ? helpText : "")
    // Keep the wrapping row's allocated width out of parent layout negotiation.
    implicitWidth: 320
    implicitHeight: row.height + 1 + (support.visible ? Theme.spacingXs + support.implicitHeight : 0)
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignTop

    RowLayout {
        id: row
        width: parent.width
        height: Math.max(Theme.formHeight, implicitHeight)
        spacing: Theme.spacingSm
        GlyphLabel {
            objectName: "formFieldPurpose"
            visible: field.icon.length > 0
            glyph: field.icon
            Layout.preferredWidth: Theme.formIconSize
            Layout.preferredHeight: Theme.formIconSize
            font.pixelSize: Theme.formIconSize
            Accessible.ignored: true
        }
        ThemeText {
            objectName: "formFieldLabel"
            Layout.preferredWidth: Math.min(implicitWidth, field.width * 0.24)
            Layout.minimumWidth: 0
            Layout.maximumWidth: field.width * 0.24
            visible: field.label.length > 0
            text: field.requiredInput ? qsTr("%1 *").arg(field.label) : field.label
            font.pixelSize: Theme.formLabelSize
            font.weight: Theme.fontWeightMedium
            color: Theme.mutedText
            wrapMode: Text.Wrap
            // The native input exposes the full label once, without duplication.
            Accessible.ignored: true
        }
        ColumnLayout {
            id: editorHost
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0
        }
        FlatIconButton {
            objectName: "formFieldCopy"
            visible: field.copyAvailable
            enabled: field.copyEnabled
            Layout.preferredWidth: Theme.formActionSize
            Layout.preferredHeight: Theme.formActionSize
            iconSize: Theme.formActionIconSize
            icon: "content_copy"
            accessibleName: qsTr("Copy %1").arg(field.accessibleName)
            // Read-only rows cannot be selected by Tab. Keep their named
            // commands in Alt+J instead of scoping them to an unreachable field.
            commandScope: field.editorAvailable ? field : null
            accessKey: field.editorAvailable ? "C" : ""
            onClicked: field.copyRequested()
        }
        FlatIconButton {
            objectName: "formFieldHelp"
            visible: field.showHelpButton
            Layout.preferredWidth: Theme.formActionSize
            Layout.preferredHeight: Theme.formActionSize
            iconSize: Theme.formActionIconSize
            icon: field.helpOpen ? "expand_less" : "help_outline"
            accessibleName: qsTr("Help: %1").arg(field.accessibleName)
            Accessible.description: field.helpText
            commandScope: field.editorAvailable ? field : null
            accessKey: field.editorAvailable ? "H" : ""
            onClicked: field.helpOpen = !field.helpOpen
        }
    }
    Rectangle {
        objectName: "formFieldSeparator"
        anchors.top: row.bottom
        width: parent.width
        height: 1
        color: Theme.border
        Accessible.ignored: true
    }
    ThemeText {
        id: support
        objectName: "formFieldSupport"
        anchors.top: row.bottom
        anchors.topMargin: 1 + Theme.spacingXs
        width: parent.width
        visible: field.message.length > 0
        text: field.message
        font.pixelSize: Theme.formSupportSize
        color: field.errorText.length > 0 ? Theme.danger : Theme.mutedText
        wrapMode: Text.Wrap
    }
    Binding {
        target: field.editor
        property: "rowEmbedded"
        value: true
        when: field.editor instanceof TextField || field.editor instanceof TextEditor || field.editor instanceof DropDownList
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: field.editor
        property: "Accessible.name"
        value: field.accessibleName
        when: field.editor !== null && field.accessibleName.length > 0
        restoreMode: Binding.RestoreBindingOrValue
    }
    Binding {
        target: field.editor
        property: "Accessible.description"
        value: [field.requiredInput ? qsTr("Required") : "", field.helpText, field.errorText || field.statusText].filter(Boolean).join(". ")
        when: field.editor !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
