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
    listComponent: Ui.ChooserListPane {
        id: pane
        chooserController: content.controller
        resultModel: content.controller.filteredResultsModel
        filterText: content.controller.filterText
        placeholder: qsTr("Search recent updates…")
        powerVisible: false
        refreshing: content.controller.loading
        preserveViewportOnAppend: true
        emptyIcon: "history"
        emptyState: content.controller.errorText ? "unavailable" : content.controller.loading ? "loading" : !content.controller.available ? "unavailable" : filterText ? "filtered" : "empty"
        emptyText: content.controller.errorText || (!content.controller.available ? qsTr("Update history has not been published") : qsTr("No recorded updates"))
        status: content.controller.loading ? qsTr("Reading update history…") : content.controller.countLabel
        feedbackScope: content
        onListNearEndChanged: if (listNearEnd) content.controller.loadMore()
        listFooterComponent: Component {
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.ActionButton {
                    objectName: "updateLoadMore"
                    label: qsTr("Load more updates")
                    icon: "expand_more"
                    accessKey: "L"
                    visible: !!content.controller.cursor
                    enabled: visible && !content.controller.loading
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
                readonly property var run: resultData.metadata.run
                readonly property string group: Presentation.dateGroup(run.job.started_at, content.controller.nowMs)
                readonly property var previous: index > 0 ? content.controller.filteredResults[index - 1] : null
                width: ListView.view.width
                Ui.SectionHeading {
                    objectName: "updateDate:" + groupRow.resultData.id
                    width: parent.width
                    visible: !groupRow.previous || groupRow.group !== Presentation.dateGroup(groupRow.previous.metadata.run.job.started_at, content.controller.nowMs)
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
                        subtitle: Presentation.rowSubtitle(groupRow.run, content.controller.nowMs)
                    }
                }
            }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedRun ? content.controller.selectedRun.title : qsTr("Updates")
        subtitle: content.controller.selectedRun ? Presentation.label(content.controller.selectedRun.job.operation) : ""
        icon: content.controller.selectedRun ? Presentation.outcomeIcon(content.controller.selectedRun.outcome) : "history"
        actions: content.controller.detailActions.filter(action => action.id !== "inspect")
        Ui.DetailFlickable {
            anchors.fill: parent
            viewMemory: content.controller.viewMemory
            memoryTab: "details"
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                Ui.DetailCard {
                    property bool informationOnly: true
                    objectName: "updateRecordedOutcome"
                    title: qsTr("Recorded outcome")
                    entries: {
                        const run = content.controller.selectedRun;
                        return run ? [
                            {label: qsTr("Status · outcome"), value: Presentation.label(run.job.status) + " · " + Presentation.label(run.outcome)},
                            {label: qsTr("Phase"), value: Presentation.label(run.job.phase)},
                            {label: qsTr("Started"), value: content.controller.timeLabel(run.job.started_at)},
                            {label: qsTr("Duration"), value: Presentation.durationLabel(run, content.controller.nowMs)},
                            ...(!Presentation.isRunning(run) && run.job.finished_at !== null ? [{label: qsTr("Finished"), value: content.controller.timeLabel(run.job.finished_at)}] : []),
                            {label: qsTr("Run identity"), value: run.job.id},
                            {label: qsTr("Exit code"), value: Presentation.exitLabel(run.job.exit_code)}
                        ] : [];
                    }
                }
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    title: qsTr("Components")
                    visible: !!content.controller.selectedRun && content.controller.selectedRun.components.length > 0
                    Repeater {
                        model: content.controller.selectedRun ? content.controller.selectedRun.components : []
                        Ui.ThemeText {
                            required property var modelData
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            textFormat: Text.PlainText
                            text: modelData.name + " · " + Presentation.label(modelData.phase) + "\n"
                                + (modelData.before || qsTr("Unknown")) + " → " + (modelData.after || qsTr("Unknown"))
                                + (modelData.changed ? " · " + qsTr("Changed in this run") : "")
                                + (modelData.error ? "\n" + modelData.error : "")
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
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    objectName: "updateRunLog"
                    title: qsTr("Run log")
                    visible: content.controller.selectedLogLoading || !!content.controller.selectedLogError || !!content.controller.selectedLog
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        objectName: "updateRunLogText"
                        text: content.controller.selectedLogLoading ? qsTr("Reading log…") : content.controller.selectedLogError || content.controller.selectedLog
                    }
                }
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    title: qsTr("Current status")
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: {
                            const state = content.controller.barController ? content.controller.barController.updates : null;
                            if (!state || !state.available) return qsTr("Current update status unavailable");
                            if (state.error) return state.error;
                            if ((state.jobs || []).some(job => job.status === "running")) return qsTr("An update job is running. Historical outcomes do not describe its completion.");
                            return state.ready ? qsTr("A checked candidate is ready. This does not mean it is active or booted.") : qsTr("No checked candidate is currently reported. Historical staging is not proof of the running system.");
                        }
                    }
                }
            }
        }
    }
}
