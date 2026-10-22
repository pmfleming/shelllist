import QtQuick
import QtQuick.Layouts

// Shared passive row. The contained native editor remains the field identity.
Item {
    id: field
    default property alias content: row.content
    property Item editor: row.controlItem
    property string label: ""
    property string icon: ""
    property string accessibleName: label
    property bool requiredInput: false
    property string supportingText: (editor as TextField)?.supportingText || (editor as TextEditor)?.supportingText || (editor as DropDownList)?.supportingText || ""
    property string errorText: (editor as TextField)?.errorText || (editor as TextEditor)?.errorText || (editor as DropDownList)?.errorText || ""
    property string statusText: ""
    property string statusTone: "info"
    property bool separatorVisible: true
    property string readOnlyReason: ""
    property bool helpOpen: false
    property bool helpOnFocus: false
    property bool showHelpButton: !helpOnFocus && helpText.length > 0
    property bool copyAvailable: false
    property bool copyEnabled: true
    signal copyRequested
    readonly property FieldEditSession editorSession: (editor as TextField)?.editSession || (editor as IpField)?.editSession || (editor as TextEditor)?.editSession || (editor as DropDownList)?.editSession || (editor as SegmentedControl)?.editSession || (editor as ValueSlider)?.editSession || (editor as LabeledValueSlider)?.editSession || null
    readonly property bool editorAvailable: editorSession?.available ?? false
    readonly property string helpText: [readOnlyReason, supportingText].filter(Boolean).join(". ")
    readonly property string message: errorText || statusText
    implicitWidth: 320
    implicitHeight: row.height + (support.visible ? Theme.spacingXs + support.implicitHeight : 0)
    Layout.minimumWidth: 0
    Layout.alignment: Qt.AlignTop

    FieldRow {
        id: row
        width: parent.width
        height: implicitHeight
        label: field.requiredInput ? qsTr("%1 *").arg(field.label) : field.label
        labelObjectName: "formFieldLabel"
        icons: field.icon.length ? [field.icon] : []
        separatorVisible: field.separatorVisible
        accessoriesVisible: field.copyAvailable || field.showHelpButton
        accessories: [
            FlatIconButton {
                objectName: "formFieldCopy"
                visible: field.copyAvailable
                enabled: field.copyEnabled
                Layout.preferredWidth: Theme.formActionSize
                Layout.preferredHeight: Theme.formActionSize
                iconSize: Theme.formActionIconSize
                icon: "content_copy"
                accessibleName: qsTr("Copy %1").arg(field.accessibleName)
                commandScope: field.editorAvailable ? field : null
                accessKey: field.editorAvailable ? "C" : ""
                onClicked: field.copyRequested()
            },
            FlatIconButton {
                objectName: "formFieldHelp"
                visible: field.showHelpButton
                enabled: field.helpText.length > 0
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
        ]
    }
    // Explicit Help may disclose content. Automatic errors/status never resize it.
    ThemeText {
        id: support
        objectName: "formFieldSupport"
        anchors.top: row.bottom
        anchors.topMargin: Theme.spacingXs
        width: parent.width
        visible: field.helpOpen && field.helpText.length > 0
        text: field.helpText
        textFormat: Text.PlainText
        font.pixelSize: Theme.formSupportSize
        color: Theme.mutedText
        wrapMode: Text.Wrap
    }
    FeedbackSource {
        objectName: "formFieldContext"
        active: field.helpOnFocus && ((field.editorSession?.focused ?? false)
            || ((field.editorSession?.navigation?.activeFocus ?? false)
                && field.editorSession.navigation.currentTarget === field.editor))
        text: field.helpText
        briefText: text
        priority: 1 // Routine context stays below operation and validation feedback.
    }
    FeedbackSource {
        text: field.message
        summaryText: qsTr("%1 needs attention").arg(field.accessibleName)
        tone: field.errorText.length ? "error" : field.statusTone
    }
    Binding {
        target: field.editor
        property: "rowEmbedded"
        value: true
        when: field.editor instanceof TextField || field.editor instanceof IpField || field.editor instanceof TextEditor || field.editor instanceof DropDownList
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
        value: [field.requiredInput ? qsTr("Required") : "", field.helpText, field.message].filter(Boolean).join(". ")
        when: field.editor !== null
        restoreMode: Binding.RestoreBindingOrValue
    }
}
