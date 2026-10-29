pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.ActionDetailsPane {
    id: pane
    required property UpdateController controller
    chooserController: controller
    uiScale: 1
    contentAvailable: controller.settingsOpen || controller.hasSelection
    title: controller.settingsOpen ? qsTr("Updates") : controller.selectedIsOverview ? qsTr("Now") : controller.selectedResult ? controller.selectedResult.title : qsTr("Updates")
    subtitle: controller.settingsOpen ? qsTr("History filters & display") : controller.selectedIsOverview ? qsTr("Current observations · read only") : controller.selectedRun ? Presentation.label(controller.selectedRun.job.operation) : ""
    icon: controller.settingsOpen ? "settings" : controller.selectedIsOverview ? "dashboard" : controller.selectedRun ? Presentation.outcomeIcon(controller.selectedRun.outcome) : "history"
    actions: controller.settingsOpen ? [] : controller.detailActions.filter(action => action.id !== "inspect").map(action => action.id === "copy-log"
        ? Object.assign({}, action, {enabled: !!controller.selectedLog && !controller.selectedLogLoading && !controller.selectedLogError}) : action)
    readonly property bool applicationsSelected: !controller.settingsOpen && controller.selectedIsOverview && controller.detailsTab === "applications"
    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.controller.detailTabs.length > 1 ? pane.controlHeight : 0
        sectionSpacing: pane.controller.detailTabs.length > 1 ? pane.sectionSpacing : 0
        selectedValue: pane.controller.detailsTab
        tabs: pane.controller.detailTabs
        onSelected: function(value) { pane.controller.selectDetailsTab(value); }
        Loader {
            anchors.fill: parent
            asynchronous: true
            sourceComponent: pane.applicationsSelected ? applicationsPage : scrollingPage
        }
    }
    Component {
        id: applicationsPage
        UpdateApplications { controller: pane.controller }
    }
    Component {
        id: scrollingPage
        Ui.DetailFlickable {
            objectName: "updateDetailsScroll"
            viewMemory: pane.controller.viewMemory
            memoryTab: pane.controller.pageKey
            Loader {
                width: parent.width
                asynchronous: true
                sourceComponent: pane.controller.settingsOpen ? settingsPage
                    : pane.controller.selectedIsOverview ? overviewPage
                    : pane.controller.selectedQuietGroup ? quietPage
                    : !pane.controller.selectedRun ? null
                    : pane.controller.detailsTab === "changes" ? changesPage
                    : pane.controller.detailsTab === "log" ? logPage : summaryPage
            }
        }
    }
    Component {
        id: settingsPage
        UpdateHistoryControls { controller: pane.controller }
    }
    Component {
        id: overviewPage
        UpdateOverview { controller: pane.controller }
    }
    Component {
        id: quietPage
        Ui.DetailRows {
            objectName: "updateQuietGroup"
            title: qsTr("Routine no-change checks")
            rows: {
                const group = pane.controller.selectedQuietGroup;
                return group ? [{label: qsTr("Loaded runs"), value: String(group.ids.length)},
                    {label: qsTr("Update job"), value: Presentation.label(group.first.lane)},
                    {label: qsTr("Newest"), value: pane.controller.timeLabel(group.first.job.started_at)},
                    {label: qsTr("Oldest"), value: pane.controller.timeLabel(group.last.job.started_at)},
                    {label: qsTr("Scope"), value: qsTr("Consecutive same-day checks in loaded history")}] : [];
            }
        }
    }
    Component {
        id: summaryPage
        Column {
            spacing: Ui.Theme.cardGap
            Ui.DetailRows {
                objectName: "updateRecordedOutcome"
                title: qsTr("Recorded outcome")
                rows: {
                    const run = pane.controller.selectedRun;
                    return run ? [
                        {label: qsTr("Outcome"), value: Presentation.label(run.outcome)},
                        {label: qsTr("Changes"), value: Presentation.componentCount(run)},
                        {label: qsTr("Job status"), value: Presentation.label(run.job.status)},
                        {label: qsTr("Phase"), value: Presentation.label(run.job.phase)},
                        ...(run.failed_stage ? [{label: qsTr("Failed stage"), value: Presentation.label(run.failed_stage)}] : []),
                        ...(run.job.operation === "manual-rebuild" ? [{label: qsTr("Deployment recorded"), value: run.deployed === true ? qsTr("Yes") : run.deployed === false ? qsTr("No") : qsTr("Not recorded")}] : []),
                        {label: qsTr("Started"), value: pane.controller.timeLabel(run.job.started_at)},
                        {label: qsTr("Duration"), value: Presentation.durationLabel(run, pane.controller.nowMs)},
                        ...(!Presentation.isRunning(run) && run.job.finished_at !== null ? [{label: qsTr("Finished"), value: pane.controller.timeLabel(run.job.finished_at)}] : []),
                        {label: qsTr("Exit code"), value: Presentation.exitLabel(run.job.exit_code)},
                        {label: qsTr("Run identity"), value: run.job.id}
                    ] : [];
                }
            }
            Ui.DetailRows {
                title: qsTr("Failure and later recovery")
                visible: rows.length > 0
                rows: pane.controller.selectedRun ? (pane.controller.selectedRun.issues || []).map(issue => ({
                    label: issue.component === null ? qsTr("Run") : pane.controller.selectedRun.components[issue.component].name,
                    value: Presentation.issueLabel(issue, pane.controller.nowMs)
                })) : []
            }
            Ui.DetailRows {
                title: qsTr("Diagnostics")
                visible: !!pane.controller.selectedRun && !!pane.controller.selectedRun.job.error
                rows: [{label: qsTr("Run error"), value: pane.controller.selectedRun ? pane.controller.selectedRun.job.error : ""}]
            }
        }
    }
    Component {
        id: changesPage
        Column {
            UpdateComponents {
                controller: pane.controller
                visible: !!pane.controller.selectedRun && pane.controller.selectedRun.components.length > 0
            }
            Ui.ContentState {
                width: parent.width
                visible: !!pane.controller.selectedRun && pane.controller.selectedRun.components.length === 0
                icon: "view_list"
                text: qsTr("No component changes recorded")
            }
        }
    }
    Component {
        id: logPage
        UpdateLog { controller: pane.controller }
    }
}
