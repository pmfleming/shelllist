pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Column {
    id: page
    required property UpdateController controller
    readonly property var overview: controller.overview
    readonly property var git: overview ? overview.git || null : null
    readonly property var applications: overview ? overview.applications || null : null
    spacing: Ui.Theme.cardGap
    Ui.DetailColumnCard {
        property bool informationOnly: true
        objectName: "updateFreshnessOverview"
        visible: page.controller.detailsTab === "overview"
        title: qsTr("Update status")
        helpText: qsTr("Comparisons describe the last reported source, not every upstream release. Refresh only reads evidence; it never fetches Git, checks releases or installs updates. Current state is independent of history filters and recorded run outcomes.")
        Repeater {
            model: [
                {key: "git", label: qsTr("Local Git"), value: Presentation.gitSummary(page.git), detail: page.git && page.git.available ? qsTr("Configuration repository · cached local tracking ref") : qsTr("No repository evidence available")},
                {key: "ai", label: qsTr("AI tools"), value: Presentation.toolsSummary(page.overview ? page.overview.tools : []), detail: qsTr("Managed vendor tools · per-tool source and check time")},
                {key: "applications", label: qsTr("Applications"), value: page.applications && page.applications.available ? qsTr("%1 packages · active generation").arg(page.applications.total) : qsTr("Application inventory not reported"), detail: qsTr("Package metadata from the active NixOS generation; system and Home Manager declarations only")},
                {key: "system", label: qsTr("System"), value: Presentation.systemSummary(page.overview, page.controller.currentState), detail: qsTr("Booted, active and next boot remain separate")}
            ]
            Ui.FieldRow {
                id: area
                required property var modelData
                objectName: "updateArea:" + modelData.key
                label: modelData.label
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: area.modelData.value
                    font.pixelSize: Ui.Theme.formValueSize
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    Accessible.name: area.modelData.label + ": " + text
                    Accessible.description: area.modelData.detail
                }
            }
        }
    }
    Ui.DetailRows {
        objectName: "updateGitOverview"
        visible: page.controller.detailsTab === "git"
        title: qsTr("Configuration repository")
        helpText: qsTr("Only the configured system repository is reported, not every local project. Distance compares local cached tracking refs; no network fetch occurs. Git working-tree state is informational, not approval or deployment evidence.")
        rows: !page.git || !page.git.available ? [
            {label: qsTr("Comparison"), value: qsTr("Repository comparison not reported")},
            {label: qsTr("Diagnostics"), value: page.git && page.git.error ? page.git.error : qsTr("Requires repository evidence from the worker")}
        ] : [
            {label: qsTr("Distance"), value: Presentation.gitSummary(page.git)},
            {label: qsTr("Branch"), value: page.git.branch || qsTr("Not reported")},
            {label: qsTr("Compared with"), value: page.git.upstream || qsTr("No tracked upstream")},
            {label: qsTr("Local revision"), value: page.git.revision || qsTr("Not recorded")},
            {label: qsTr("Working tree"), value: page.git.dirty ? qsTr("Git reports local changes") : qsTr("Git reports no local changes")},
            {label: qsTr("Observed locally"), value: page.controller.timeLabel(page.git.observed_at)},
            {label: qsTr("Remote checked"), value: page.controller.timeLabel(page.git.target_observed_at)},
            {label: qsTr("Path"), value: page.git.path || qsTr("Not reported")}
        ]
    }
    UpdateApplications {
        visible: page.controller.detailsTab === "applications"
        controller: page.controller
    }
}
