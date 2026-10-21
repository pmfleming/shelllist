pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Column {
    id: overview
    required property UpdateController controller
    readonly property var snapshot: controller.currentState
    readonly property var candidate: Presentation.deferredCandidate(snapshot)
    spacing: Ui.Theme.spacingMd

    Ui.ThemeText {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: qsTr("Current worker observations, independent of historical outcomes. Unknown fields are not proof of deployment or recovery.")
    }
    Ui.ThemeText {
        width: parent.width
        visible: !!text
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: Ui.Theme.warning
        text: overview.snapshot && overview.snapshot.error ? overview.snapshot.error : ""
    }
    Repeater {
        model: ["system", "ai-tools", "ai-tools-stale"]
        Ui.DetailColumnCard {
            id: laneCard
            required property string modelData
            readonly property var lane: Presentation.laneOverview(overview.snapshot, modelData, overview.controller.nowMs)
            property bool informationOnly: true
            objectName: "updateLane:" + modelData
            title: lane.title
            Ui.FieldRow {
                label: qsTr("State")
                Ui.ThemeText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: laneCard.lane.status
                    Accessible.name: qsTr("State: %1").arg(text)
                }
            }
            Ui.FieldRow {
                label: qsTr("Last observation")
                Ui.ThemeText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: [laneCard.lane.timing, laneCard.lane.operation].filter(Boolean).join(" · ")
                    Accessible.name: qsTr("Last observation: %1").arg(text)
                }
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                visible: !!text
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                color: Ui.Theme.warning
                text: laneCard.lane.error
            }
        }
    }
    UpdateOverviewDetails { width: parent.width; controller: overview.controller }
    Ui.DetailColumnCard {
        property bool informationOnly: true
        objectName: "updateDeferredCandidate"
        title: qsTr("Deferred system candidate")
        Ui.ThemeText {
            objectName: "updateCandidateStatus"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: !overview.candidate ? qsTr("Candidate status unavailable") : overview.candidate.ready
                ? qsTr("Checked and ready; this does not mean active, staged or booted.") : qsTr("No checked candidate reported")
        }
        Repeater {
            model: overview.candidate && overview.candidate.ready ? [
                {key: "waiting", label: qsTr("Waiting"), value: Presentation.ageLabel(overview.candidate.created_at, overview.controller.nowMs) + " · " + overview.controller.timeLabel(overview.candidate.created_at)},
                {key: "application", label: qsTr("Application"), value: overview.candidate.auto_apply === true ? qsTr("Automatic") : overview.candidate.auto_apply === false ? qsTr("Approval required") : qsTr("Not reported")},
                {key: "revision", label: qsTr("Revision"), value: overview.candidate.revision || qsTr("Not reported")},
                {key: "base", label: qsTr("Base hash"), value: overview.candidate.base_hash || qsTr("Not reported")},
                {key: "system", label: qsTr("System path"), value: overview.candidate.system || qsTr("Not reported")}
            ] : []
            Ui.FieldRow {
                id: candidateField
                required property var modelData
                objectName: "updateCandidate:" + modelData.key
                label: modelData.label
                Ui.ThemeText {
                    Layout.fillWidth: true
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    text: candidateField.modelData.value
                    Accessible.name: candidateField.modelData.label + ": " + text
                }
            }
        }
    }
}
