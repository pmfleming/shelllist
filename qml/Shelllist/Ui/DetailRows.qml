pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// Passive facts use the same left-label/right-value composition as settings.
// Unlike DetailGrid, long values wrap without losing diagnostic identities.
DetailColumnCard {
    id: card
    property bool informationOnly: true
    property var rows: []
    FeedbackSource { id: explanation }
    Repeater {
        model: card.rows || []
        FieldRow {
            id: row
            required property var modelData
            label: modelData.label
            subtitle: modelData.subtitle || ""
            ThemeText {
                Layout.fillWidth: true
                text: row.modelData.value || "—"
                color: row.modelData.valueColor || Theme.text
                font.pixelSize: Theme.formValueSize
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                Accessible.name: row.modelData.label + ": " + text
                Accessible.description: row.modelData.description || ""
            }
            accessories: FeedbackButton {
                visible: !!row.modelData.description
                accessibleName: row.modelData.label
                icon: "info"
                feedback: explanation
                feedbackText: row.modelData.description || ""
            }
        }
    }
}
