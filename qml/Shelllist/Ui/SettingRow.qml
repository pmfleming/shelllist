import QtQuick

// Compatibility names only: composition, Help and feedback belong to FormField.
FormField {
    id: row
    property string title: ""
    property string subtitle: ""
    property color subtitleColor: Theme.mutedText
    property bool compact: false
    default property alias controls: row.content
    readonly property bool operationalSubtitle: subtitleColor === Theme.warning || subtitleColor === Theme.danger
    label: title
    supportingText: operationalSubtitle ? "" : subtitle
    errorText: subtitleColor === Theme.danger ? subtitle : ""
    statusText: subtitleColor === Theme.warning ? subtitle : ""
    statusTone: "warning"
    // Guidance/operation transitions must not change the editor's allocation.
    showHelpButton: true
}
