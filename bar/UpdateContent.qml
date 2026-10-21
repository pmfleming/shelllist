pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

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
        status: content.controller.loading ? qsTr("Reading update history…") : qsTr("%1 recent runs · read only").arg(content.controller.entries.length)
        feedbackScope: content
        onListNearEndChanged: if (listNearEnd) content.controller.loadMore()
        listFooterComponent: Ui.ActionButton {
            objectName: "updateLoadMore"
            label: qsTr("Load more updates")
            icon: "expand_more"
            accessKey: "L"
            visible: !!content.controller.cursor
            enabled: !content.controller.loading
            onClicked: content.controller.loadMore()
        }
        rowDelegate: Ui.ResultRow {
            id: row
            required property var resultData
            objectName: "updateRun:" + resultData.id
            listPane: pane
            rowHeight: pane.delegateHeight
            leadingIcon: resultData.icon
            accessibleName: resultData.title + ". " + resultData.subtitle
            Ui.ResultLabel { title: row.resultData.title; subtitle: row.resultData.subtitle }
        }
    }
    detailsComponent: Ui.ActionDetailsPane {
        chooserController: content.controller
        uiScale: 1
        title: content.controller.selectedRun ? content.controller.selectedRun.title : qsTr("Updates")
        subtitle: content.controller.selectedRun ? content.controller.selectedRun.job.operation : ""
        icon: "history"
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
                    title: qsTr("Recorded outcome")
                    entries: {
                        const run = content.controller.selectedRun;
                        return run ? [
                            {label: qsTr("Outcome"), value: run.title},
                            {label: qsTr("Phase"), value: run.job.phase},
                            {label: qsTr("Started"), value: content.controller.timeLabel(run.job.started_at)},
                            {label: qsTr("Finished"), value: content.controller.timeLabel(run.job.finished_at)},
                            {label: qsTr("Run identity"), value: run.job.id},
                            {label: qsTr("Exit code"), value: run.job.exit_code === null ? qsTr("Not recorded") : String(run.job.exit_code)}
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
                            text: modelData.name + " · " + modelData.phase + "\n"
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
                    title: qsTr("Worker journal")
                    visible: !!content.controller.selectedLog
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        textFormat: Text.PlainText
                        text: content.controller.selectedLog
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
                Ui.DetailColumnCard {
                    property bool informationOnly: true
                    title: qsTr("History coverage")
                    Ui.ThemeText { Layout.fillWidth: true; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: content.controller.coverage }
                }
            }
        }
    }
}
