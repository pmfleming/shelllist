pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.ProviderChooserSurface {
    id: content
    required property UpdateController controller
    chooserController: controller
    feedbackScope: content
    sessionContext: controller.selectedResult ? controller.selectedResult.key : ""
    additionalCommandItem: content.listItem
    commandsWithoutDetails: true
    Ui.FeedbackSource {
        text: content.controller.errorText
        briefText: qsTr("Update history unavailable")
        tone: "error"
    }
    Ui.FeedbackSource {
        text: content.controller.warningText
        briefText: content.controller.warningBrief
        summaryText: content.controller.warningBrief
        tone: "warning"
    }
    Ui.FeedbackSource {
        text: content.controller.copyError
        briefText: qsTr("Could not copy update details")
        tone: "error"
    }
    Ui.FeedbackSource {
        text: content.controller.selectedIsOverview ? content.controller.overviewError || (content.controller.overview ? content.controller.overview.error || "" : "") : ""
        briefText: qsTr("Worker overview unavailable")
        tone: "error"
    }
    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.filteredResultsModel
        filterText: content.controller.filterText
        placeholder: qsTr("Search runs, today or YYYY-MM-DD…")
        listOptionsComponent: Component { UpdateHistoryControls { controller: content.controller } }
        powerVisible: false
        refreshing: content.controller.loading
        preserveViewportOnAppend: true
        emptyIcon: "history"
        emptyState: content.controller.errorText ? "unavailable" : content.controller.loading ? "loading" : !content.controller.available ? "unavailable" : content.controller.historyFiltered ? "filtered" : "empty"
        emptyText: content.controller.errorText || (!content.controller.available ? qsTr("Update history has not been published") : content.controller.historyFiltered ? qsTr("No matching updates") : qsTr("No recorded updates"))
        status: content.controller.loading ? qsTr("Reading update history…") : content.controller.countLabel
        feedbackScope: content
        onListNearEndChanged: if (listNearEnd) content.controller.loadMore()
        listFooterComponent: Component {
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.ContentState {
                    width: parent.width
                    visible: content.controller.entries.length === 0
                    active: content.controller.uiActive
                    icon: "history"
                    kind: pane.emptyState
                    text: pane.emptyText
                }
                Ui.ActionButton {
                    objectName: "updateLoadMore"
                    label: qsTr("Load more updates")
                    icon: "expand_more"
                    accessKey: "L"
                    visible: !!content.controller.cursor
                    enabled: content.controller.canLoadMore
                    onClicked: content.controller.loadMore()
                }
                Ui.ThemeText {
                    objectName: "updateHistoryCoverage"
                    width: parent.width
                    visible: !!text
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: content.controller.coverage
                }
            }
        }
        rowDelegate: Component {
            Column {
                id: groupRow
                required property int index
                required property var resultData
                readonly property var run: resultData.metadata.run || (resultData.metadata.quietGroup ? resultData.metadata.quietGroup.first : null)
                readonly property string group: run ? Presentation.dateGroup(run.job.started_at, content.controller.nowMs) : ""
                readonly property var previous: index > 0 ? content.controller.filteredResults[index - 1] : null
                width: ListView.view.width
                Ui.SectionHeading {
                    objectName: "updateDate:" + groupRow.resultData.id
                    width: parent.width
                    visible: !!groupRow.run && (!groupRow.previous || !(groupRow.previous.metadata.run || groupRow.previous.metadata.quietGroup) || groupRow.group !== Presentation.dateGroup((groupRow.previous.metadata.run || groupRow.previous.metadata.quietGroup.first).job.started_at, content.controller.nowMs))
                    height: implicitHeight + 2 * Ui.Theme.spacingSm
                    title: groupRow.group
                }
                Ui.ResultRow {
                    index: groupRow.index
                    width: parent.width
                    objectName: "updateRun:" + groupRow.resultData.id
                    listPane: pane
                    rowHeight: pane.delegateHeight
                    leadingIcon: groupRow.resultData.icon
                    accessibleName: groupRow.resultData.title + ". " + label.subtitle
                    Ui.ResultLabel {
                        id: label
                        title: groupRow.resultData.title
                        subtitle: groupRow.resultData.metadata.quietGroup ? groupRow.resultData.subtitle : groupRow.run ? Presentation.rowSubtitle(groupRow.run, content.controller.nowMs) : Presentation.nowSummary(content.controller.currentState, content.controller.nowMs)
                    }
                }
            }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedIsOverview ? qsTr("Now") : content.controller.selectedResult ? content.controller.selectedResult.title : qsTr("Updates")
        subtitle: content.controller.selectedIsOverview ? qsTr("Current worker status") : content.controller.selectedRun ? Presentation.label(content.controller.selectedRun.job.operation) : ""
        icon: content.controller.selectedIsOverview ? "today" : content.controller.selectedRun ? Presentation.outcomeIcon(content.controller.selectedRun.outcome) : "history"
        actions: content.controller.detailActions.filter(action => action.id !== "inspect").map(action => action.id === "copy-log"
            ? Object.assign({}, action, {enabled: !!content.controller.selectedLog && !content.controller.selectedLogLoading && !content.controller.selectedLogError}) : action)
        Ui.DetailFlickable {
            objectName: "updateDetailsScroll"
            anchors.fill: parent
            viewMemory: content.controller.viewMemory
            memoryTab: "details"
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                UpdateOverview {
                    width: parent.width
                    controller: content.controller
                    visible: content.controller.selectedIsOverview
                }
                Ui.DetailCard {
                    objectName: "updateQuietGroup"
                    visible: !!content.controller.selectedQuietGroup
                    title: qsTr("Routine no-change checks")
                    entries: {
                        const group = content.controller.selectedQuietGroup;
                        return group ? [{label: qsTr("Loaded runs"), value: String(group.ids.length)},
                            {label: qsTr("Lane"), value: Presentation.label(group.first.lane)},
                            {label: qsTr("Newest"), value: content.controller.timeLabel(group.first.job.started_at)},
                            {label: qsTr("Oldest"), value: content.controller.timeLabel(group.last.job.started_at)},
                            {label: qsTr("Scope"), value: qsTr("Consecutive same-day checks in loaded history; expand to review each run.")}] : [];
                    }
                }
                Ui.DetailCard {
                    visible: !!content.controller.selectedRun
                    property bool informationOnly: true
                    objectName: "updateRecordedOutcome"
                    title: qsTr("Recorded outcome")
                    entries: {
                        const run = content.controller.selectedRun;
                        return run ? [
                            {label: qsTr("Status · outcome"), value: Presentation.label(run.job.status) + " · " + Presentation.label(run.outcome)},
                            {label: qsTr("Phase"), value: Presentation.label(run.job.phase)},
                            ...(run.failed_stage ? [{label: qsTr("Failed stage"), value: Presentation.label(run.failed_stage)}] : []),
                            ...(run.job.operation === "manual-rebuild" ? [{label: qsTr("Deployment recorded"), value: run.deployed === true ? qsTr("Yes") : run.deployed === false ? qsTr("No") : qsTr("Not recorded")}] : []),
                            {label: qsTr("Started"), value: content.controller.timeLabel(run.job.started_at)},
                            {label: qsTr("Duration"), value: Presentation.durationLabel(run, content.controller.nowMs)},
                            ...(!Presentation.isRunning(run) && run.job.finished_at !== null ? [{label: qsTr("Finished"), value: content.controller.timeLabel(run.job.finished_at)}] : []),
                            {label: qsTr("Run identity"), value: run.job.id},
                            {label: qsTr("Exit code"), value: Presentation.exitLabel(run.job.exit_code)}
                        ] : [];
                    }
                }
                UpdateComponents { controller: content.controller }
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    title: qsTr("Failure and recovery")
                    visible: !!content.controller.selectedRun && !!content.controller.selectedRun.issues && content.controller.selectedRun.issues.length > 0
                    Repeater {
                        model: content.controller.selectedRun ? content.controller.selectedRun.issues || [] : []
                        Ui.FieldRow {
                            id: recoveryRow
                            required property var modelData
                            label: modelData.component === null ? qsTr("Run") : content.controller.selectedRun.components[modelData.component].name
                            Ui.ThemeText {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                wrapMode: Text.Wrap
                                text: Presentation.issueLabel(recoveryRow.modelData, content.controller.nowMs)
                            }
                        }
                    }
                }
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    title: qsTr("Diagnostics")
                    visible: !!content.controller.selectedRun && !!content.controller.selectedRun.job.error
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: content.controller.selectedRun ? content.controller.selectedRun.job.error || "" : ""
                    }
                }
                UpdateLog { controller: content.controller }
            }
        }
    }
}
