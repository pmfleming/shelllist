pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Column {
    id: details
    required property UpdateController controller
    readonly property var snapshot: controller.overview
    property bool informationOnly: true
    spacing: Ui.Theme.cardGap
    Ui.ThemeText {
        width: parent.width
        visible: details.controller.detailsTab !== "applications" && details.controller.detailsTab !== "git"
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        font.pixelSize: Ui.Theme.metadataSize
        text: details.controller.overviewLoading ? qsTr("Reading worker overview…")
            : details.snapshot && details.snapshot.observed_at ? qsTr("Observed %1 · read only").arg(details.controller.timeLabel(details.snapshot.observed_at)) : qsTr("Worker overview not recorded")
    }
    Ui.DetailColumnCard {
        objectName: "updateOpenIssues"
        visible: details.controller.detailsTab === "overview"
        title: qsTr("Open issues")
        Ui.ThemeText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: !details.snapshot || !details.snapshot.history_available ? qsTr("Issue history unavailable")
                : details.snapshot.history_error ? qsTr("Some history is unreadable; recovery may be missing.")
                : qsTr("%1 of %2 unresolved issues in retained history").arg(details.snapshot.issues.length).arg(details.snapshot.issue_total)
        }
        Repeater {
            model: details.snapshot ? details.snapshot.issues : []
            Ui.FieldRow {
                id: issueRow
                required property var modelData
                objectName: "updateOpenIssue:" + modelData.run_id
                label: modelData.component
                subtitle: Presentation.label(modelData.lane) + " · " + qsTr("Failed %1").arg(details.controller.timeLabel(modelData.failed_at))
                Ui.ThemeText {
                    Layout.fillWidth: true
                    text: issueRow.modelData.error + (issueRow.modelData.incident ? "\n" + qsTr("Incident: %1").arg(issueRow.modelData.incident) : "")
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAnywhere
                }
                accessories: Ui.FlatIconButton {
                    objectName: "updateReviewIssue:" + issueRow.modelData.run_id
                    sizeRole: "secondary"
                    uiScale: Ui.Theme.expandedSecondaryActionScale
                    icon: "history"
                    accessibleName: qsTr("Review failure: %1").arg(issueRow.modelData.component)
                    onClicked: details.controller.reviewIssue(issueRow.modelData.run_id)
                }
            }
        }
    }
    Ui.DetailRows {
        objectName: "updateSystemOverview"
        title: qsTr("Booted, active and next boot")
        visible: details.controller.detailsTab === "system"
        rows: {
            const system = details.snapshot ? details.snapshot.system : null;
            if (!system) return [{label: qsTr("Deployment"), value: qsTr("System evidence not reported")}];
            return [
                {label: qsTr("Booted"), value: system.booted || qsTr("Unknown")},
                {label: qsTr("Active"), value: system.active || qsTr("Unknown")},
                {label: qsTr("System profile / next boot"), value: system.profile || qsTr("Unknown")},
                {label: qsTr("Staging"), value: system.staged_for_next_boot === true
                    ? qsTr("Staged for next boot since %1").arg(system.staged_since ? details.controller.timeLabel(system.staged_since) : qsTr("an unrecorded time"))
                    : system.staged_for_next_boot === false ? qsTr("No staged candidate reported") : qsTr("Unknown — not proof of a completed stage")},
                {label: qsTr("Pending transaction"), value: system.pending_transaction === null ? qsTr("Unknown") : system.pending_transaction ? qsTr("Recovery pending on next worker run") : qsTr("None reported")},
                {label: qsTr("Queued"), value: system.queued === null ? qsTr("Unknown") : system.queued ? qsTr("Yes") : qsTr("No")},
                {label: qsTr("System last successful check"), value: details.controller.timeLabel(system.last_successful_check)},
                {label: qsTr("Release distance"), value: qsTr("Not reported — deployment generations are not release counts")},
                ...(system.errors.length ? [{label: qsTr("Diagnostics"), value: system.errors.join("\n")}] : [])
            ];
        }
    }
    Ui.DetailRows {
        objectName: "updateBaseline"
        title: qsTr("Approved baseline")
        visible: details.controller.detailsTab === "system" && !!details.snapshot && !!details.snapshot.baseline
        rows: {
            const baseline = details.snapshot ? details.snapshot.baseline : null;
            return baseline ? [
                {label: qsTr("Validation"), value: baseline.valid === null ? qsTr("Unknown") : baseline.valid ? qsTr("Valid") : qsTr("Invalid")},
                {label: qsTr("Approved"), value: details.controller.timeLabel(baseline.approved_at)},
                {label: qsTr("Revision"), value: baseline.revision || qsTr("Not recorded")},
                ...((baseline.error || baseline.reasons.length) ? [{label: qsTr("Diagnostics"), value: [baseline.error, ...baseline.reasons].filter(Boolean).join("\n")}] : [])
            ] : [];
        }
    }
    UpdateTools {
        width: parent.width
        controller: details.controller
        visible: details.controller.detailsTab === "ai"
    }
    Column {
        width: parent.width
        visible: details.controller.detailsTab === "system"
        spacing: Ui.Theme.cardGap
        Ui.ThemeText {
            width: parent.width
            visible: !!text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            text: details.snapshot ? details.snapshot.timers_error || (!details.snapshot.timers.length ? qsTr("No timer schedule reported") : "") : qsTr("Timer schedule unavailable")
        }
        Repeater {
            model: details.snapshot ? details.snapshot.timers : []
            Ui.DetailRows {
                required property var modelData
                objectName: "updateTimer:" + modelData.unit
                title: qsTr("Scheduled check")
                rows: [
                    {label: qsTr("Timer"), value: modelData.unit || qsTr("Unknown timer")},
                    {label: qsTr("Next"), value: details.controller.timeLabel(modelData.next_at)},
                    {label: qsTr("Last trigger"), value: details.controller.timeLabel(modelData.last_at)}
                ]
            }
        }
    }
}
