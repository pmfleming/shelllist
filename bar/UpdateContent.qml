pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.ProviderChooserSurface {
    id: content
    required property UpdateController controller
    chooserController: controller
    feedbackScope: content
    sessionContext: JSON.stringify([controller.viewMemory.key, controller.pageKey])
    detailsTabEnabled: controller.detailsOpen && !controller.settingsOpen && controller.detailTabs.length > 1
    Connections {
        target: content.controller
        function onSettingsFieldRequested(field: string): void {
            Qt.callLater(function() {
                if (content.controller.uiActive && content.controller.settingsOpen && content.controller.detailsOpen)
                    content.detailsNavigation.focusSessionLocation({target: field, editing: false});
            });
        }
    }
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
        placeholder: qsTr("Search updates…")
        searchActionIcon: "settings"
        searchActionToolTip: qsTr("Update view settings: %1").arg(content.controller.filterDescription)
        searchActionActive: !content.controller.runId && (!!content.controller.laneFilter || !!content.controller.outcomeFilter)
        searchActionEnabled: !content.controller.navigationBlocked
        onSearchActionRequested: content.controller.toggleSettings()
        Ui.CommandGroup {
            Ui.ActionControl {
                accessibleName: qsTr("Filter update job")
                accessKey: "T"
                onClicked: content.controller.openSettings("updateLaneFilter")
            }
            Ui.ActionControl {
                accessibleName: qsTr("Filter update outcome")
                accessKey: "F"
                onClicked: content.controller.openSettings("updateOutcomeFilter")
            }
            Ui.ActionControl {
                accessibleName: content.controller.collapseRoutine ? qsTr("Show individual no-change checks") : qsTr("Fold routine checks")
                accessKey: "N"
                onClicked: content.controller.collapseRoutine = !content.controller.collapseRoutine
            }
            Ui.ActionControl {
                accessibleName: qsTr("Show all recent updates")
                accessKey: "A"
                onClicked: content.controller.perform("all")
            }
        }
        powerVisible: false
        refreshing: content.controller.loading
        preserveViewportOnAppend: true
        emptyIcon: "history"
        emptyState: content.controller.errorText ? "unavailable" : content.controller.loading ? "loading" : !content.controller.available ? "unavailable" : content.controller.historyFiltered ? "filtered" : "empty"
        emptyText: content.controller.errorText || (!content.controller.available ? qsTr("Update history has not been published") : content.controller.historyFiltered ? qsTr("No matching updates") : qsTr("No recorded updates"))
        status: content.controller.loading ? qsTr("Reading update history…") : content.controller.runId ? qsTr("Exact run · history filters bypassed") : content.controller.countLabel
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
                        subtitle: groupRow.resultData.metadata.quietGroup ? groupRow.resultData.subtitle : groupRow.run ? Presentation.rowSubtitle(groupRow.run, content.controller.nowMs) : qsTr("Local Git · AI tools · Applications · System")
                    }
                }
            }
        }
    }
    detailsComponent: UpdateDetails { controller: content.controller }
}
