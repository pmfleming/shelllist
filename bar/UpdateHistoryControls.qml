pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Item {
    id: controls
    implicitHeight: filterRow.implicitHeight
    required property UpdateController controller
    readonly property var lanes: [{value: "", label: qsTr("All lanes")}, {value: "system", label: qsTr("System")},
        {value: "ai-tools", label: qsTr("AI tools")}, {value: "ai-tools-stale", label: qsTr("AI stale checks")}]
    readonly property var outcomes: [{value: "", label: qsTr("All outcomes")}, {value: "problems", label: qsTr("Problems")},
        {value: "running", label: qsTr("Running")}, {value: "current", label: qsTr("No change")},
        {value: "activated", label: qsTr("Activated")}, {value: "staged", label: qsTr("Staged")},
        {value: "ready", label: qsTr("Ready")}, {value: "queued", label: qsTr("Queued")},
        {value: "failed", label: qsTr("Failed")}, {value: "partial", label: qsTr("Partial")},
        {value: "blocked", label: qsTr("Blocked")}, {value: "interrupted", label: qsTr("Interrupted")},
        {value: "available", label: qsTr("Available")}, {value: "skipped", label: qsTr("Skipped")},
        {value: "approved", label: qsTr("Approved")}, {value: "completed", label: qsTr("Completed")}]
    function openFilter(kind: string): void {
        if (!controller.uiActive || controller.navigationBlocked) return;
        menu.kind = kind;
        menu.open();
    }
    RowLayout {
        id: filterRow
        width: parent.width
        spacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: controls.controller.runId ? qsTr("Exact run · filters bypassed")
                : controls.lanes.find(option => option.value === controls.controller.laneFilter).label + " · "
                    + controls.outcomes.find(option => option.value === controls.controller.outcomeFilter).label
        }
        Ui.FlatIconButton {
            objectName: "updateLaneFilter"
            icon: "layers"
            accessibleName: qsTr("Filter update lane")
            accessKey: "T"
            onClicked: controls.openFilter("lane")
        }
        Ui.FlatIconButton {
            objectName: "updateOutcomeFilter"
            icon: "filter_alt"
            accessibleName: qsTr("Filter update outcome")
            accessKey: "F"
            onClicked: controls.openFilter("outcome")
        }
        Ui.FlatIconButton {
            objectName: "updateCollapseRoutine"
            icon: controls.controller.collapseRoutine ? "unfold_more" : "unfold_less"
            accessibleName: controls.controller.collapseRoutine ? qsTr("Show individual no-change checks") : qsTr("Collapse routine no-change checks")
            accessKey: "N"
            onClicked: if (controls.controller.uiActive && !controls.controller.navigationBlocked) controls.controller.collapseRoutine = !controls.controller.collapseRoutine
        }
    }
    Ui.ActionMenu {
        id: menu
        property string kind: "lane"
        objectName: "updateFilterMenu"
        listObjectName: "updateFilterChoices"
        y: controls.height
        actions: kind === "lane" ? controls.lanes : controls.outcomes
        accessibleName: kind === "lane" ? qsTr("Update lane") : qsTr("Update outcome")
        initialIndex: actions.findIndex(option => option.value === (kind === "lane" ? controls.controller.laneFilter : controls.controller.outcomeFilter))
        onTriggered: function(action) { controls.controller.setHistoryFilter(kind, action.value); }
    }
    Binding {
        target: controls.controller
        property: "navigationBlocked"
        value: true
        when: menu.visible
        restoreMode: Binding.RestoreBindingOrValue
    }
    Connections {
        target: controls.controller
        function onUiActiveChanged(): void { if (!controls.controller.uiActive) menu.close(); }
        function onUiSuspensionRequested(): void { menu.close(); }
    }
}
