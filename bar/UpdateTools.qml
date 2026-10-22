pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.DetailColumnCard {
    id: card
    required property UpdateController controller
    property bool informationOnly: true
    title: qsTr("Installed → latest known")
    helpText: qsTr("Only managed AI tools are counted. A release check, an installation attempt and the installed artifact are separate observations. Release distance is not inferred by subtracting version numbers. Help and Copy retain each tool's full source, timestamps and diagnostics.")
    Ui.ThemeText {
        Layout.fillWidth: true
        visible: !card.controller.overview || !card.controller.overview.tools.length
        text: qsTr("Tool comparison not reported")
        wrapMode: Text.Wrap
    }
    Repeater {
        model: card.controller.overview ? card.controller.overview.tools : []
        Ui.FormField {
            id: tool
            required property var modelData
            readonly property var freshness: modelData.freshness || ({})
            readonly property var rows: Presentation.toolRows(modelData)
            objectName: "updateInstalledTool:" + modelData.name
            Layout.fillWidth: true
            label: modelData.name || qsTr("Unknown tool")
            supportingText: rows.map(row => row.label + ": " + row.value).join("\n")
            copyAvailable: true
            onCopyRequested: card.controller.copyText(label + "\n" + supportingText, qsTr("Tool evidence copied"))
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingXs
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: (tool.modelData.installed_version || qsTr("Unknown")) + " → " + (tool.freshness.latest_version || qsTr("Not reported"))
                    font.pixelSize: Ui.Theme.formValueSize
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    Accessible.name: qsTr("%1: installed %2, latest known %3").arg(tool.label).arg(tool.modelData.installed_version || qsTr("Unknown")).arg(tool.freshness.latest_version || qsTr("Not reported"))
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: Presentation.toolFreshness(tool.modelData)
                        + (["failed", "building", "checking"].includes(tool.modelData.phase) ? " · " + Presentation.label(tool.modelData.phase) : "")
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: qsTr("Checked %1").arg(card.controller.timeLabel(tool.modelData.last_successful_check))
                    font.pixelSize: Ui.Theme.metadataSize
                    color: Ui.Theme.mutedText
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
