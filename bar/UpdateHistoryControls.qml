pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Column {
    id: controls
    required property UpdateController controller
    spacing: Ui.Theme.cardGap
    readonly property var lanes: [{value: "", label: qsTr("All jobs")}, {value: "system", label: qsTr("System")},
        {value: "ai-tools", label: qsTr("AI tools")}, {value: "ai-tools-stale", label: qsTr("AI freshness checks")}]
    readonly property var outcomes: [{value: "", label: qsTr("All outcomes")}, {value: "problems", label: qsTr("Problems")},
        {value: "running", label: qsTr("Running")}, {value: "current", label: qsTr("No change")},
        {value: "activated", label: qsTr("Activated")}, {value: "staged", label: qsTr("Staged")},
        {value: "ready", label: qsTr("Ready")}, {value: "queued", label: qsTr("Queued")},
        {value: "failed", label: qsTr("Failed")}, {value: "partial", label: qsTr("Partial")},
        {value: "blocked", label: qsTr("Blocked")}, {value: "interrupted", label: qsTr("Interrupted")},
        {value: "available", label: qsTr("Available")}, {value: "skipped", label: qsTr("Skipped")},
        {value: "approved", label: qsTr("Approved")}, {value: "completed", label: qsTr("Completed")}]
    Ui.DetailColumnCard {
        title: qsTr("History filters")
        helpText: qsTr("Filters affect recorded runs, not Now. Search supports today, yesterday, YYYY-MM-DD, on:, since: (inclusive) and before: (exclusive). Exact-run links bypass filters; saving a filter returns to history.")
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Update job")
            icon: "layers"
            Ui.DropDownList {
                objectName: "updateLaneFilter"
                Layout.fillWidth: true
                Accessible.name: qsTr("History update job")
                value: controls.controller.laneFilter
                options: controls.lanes
                onSelected: function(value) { controls.controller.setHistoryFilter("lane", value); }
            }
        }
        Ui.FormField {
            Layout.fillWidth: true
            label: qsTr("Outcome")
            icon: "filter_alt"
            Ui.DropDownList {
                objectName: "updateOutcomeFilter"
                Layout.fillWidth: true
                Accessible.name: qsTr("History outcome")
                value: controls.controller.outcomeFilter
                options: controls.outcomes
                onSelected: function(value) { controls.controller.setHistoryFilter("outcome", value); }
            }
        }
    }
    Ui.DetailColumnCard {
        title: qsTr("History display")
        Ui.ToggleRow {
            objectName: "updateCollapseRoutine"
            Layout.fillWidth: true
            title: qsTr("Fold routine checks")
            checked: controls.controller.collapseRoutine
            onClicked: controls.controller.collapseRoutine = !checked
        }
    }
    Ui.LabeledAction {
        label: qsTr("Show all recent updates")
        icon: "history"
        onClicked: controls.controller.perform("all")
    }
}
