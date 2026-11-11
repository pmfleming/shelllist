pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: card
    required property UpdateController controller
    property bool informationOnly: true
    objectName: "updateSystemVersions"
    title: qsTr("System versions")
    helpText: qsTr("Installed versions come from the active system generation, which can differ from the running kernel or compositor. Latest is the cached upstream stable release, not necessarily the version selected by your NixOS configuration or kernel branch. Refresh only reads evidence.")
    Repeater {
        model: [{name: "linux", label: qsTr("Linux kernel")}, {name: "hyprland", label: qsTr("Hyprland")}]
        Ui.FieldRow {
            id: part
            required property var modelData
            readonly property var packages: card.controller.overview && card.controller.overview.applications
                && card.controller.overview.applications.available ? card.controller.overview.applications.packages : []
            readonly property var installed: packages.filter(p => p.scope === "system" && p.name === modelData.name)
            readonly property string version: [...new Set(installed.map(p => p.version).filter(Boolean))].join(" / ")
            readonly property var release: installed.length ? installed[0].release || null : null
            objectName: "updateSystemVersion:" + modelData.name
            label: modelData.label
            readonly property string supportingText: card.helpText + "\n" + qsTr("Source: %1").arg(release ? release.source : qsTr("Not reported"))
                + "\n" + qsTr("Checked: %1").arg(card.controller.timeLabel(release ? release.checked_at : null))
                + (release && release.error ? "\n" + release.error : "")
            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingXs
                Ui.ThemeText {
                    objectName: "updateSystemInstalled"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: qsTr("Installed: %1").arg(part.version || qsTr("Not reported"))
                    font.pixelSize: Ui.Theme.formValueSize
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    Accessible.name: part.label + ": " + text
                }
                Ui.ThemeText {
                    objectName: "updateSystemLatest"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: (part.release && (part.release.stale || part.release.error)
                        ? qsTr("Last known stable: %1") : qsTr("Latest stable: %1"))
                        .arg(part.release && part.release.version ? part.release.version : qsTr("Not reported"))
                    font.pixelSize: Ui.Theme.formValueSize
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    Accessible.name: part.label + ": " + text
                    Accessible.description: part.supportingText
                }
            }
        }
    }
}
