pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: card
    required property UpdateController controller
    readonly property var applications: controller.overview ? controller.overview.applications : null
    readonly property bool available: !!applications && applications.available
    property bool informationOnly: true
    objectName: "updateApplicationsOverview"
    title: qsTr("Applications")
    helpText: qsTr("Declared local versions; latest known upstream releases. Refresh only reads.")
    helpFeedback: explanation
    Accessible.description: available ? qsTr("%1 of %2 declared packages").arg(applications.packages.length).arg(applications.total) : ""

    // One contribution for both heading and row commands; never accumulate help.
    Ui.FeedbackSource {
        id: explanation
        objectName: "updateApplicationExplanation"
        priority: 5
        active: card.controller.uiActive && card.controller.detailsOpen
        onActiveChanged: if (!active) text = ""
    }
    onVisibleChanged: if (!visible) explanation.text = ""
    onApplicationsChanged: explanation.text = ""

    Ui.ThemeText {
        objectName: "updateApplicationUnavailable"
        Layout.fillWidth: true
        visible: !card.available
        text: card.applications && card.applications.error ? card.applications.error : qsTr("Application inventory not reported")
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
    }
    Ui.FieldRow {
        Layout.fillWidth: true
        visible: card.available
        label: qsTr("Name")
        separatorVisible: false
        RowLayout {
            Layout.fillWidth: true
            Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Local"); color: Ui.Theme.mutedText }
            Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Latest"); color: Ui.Theme.mutedText }
        }
    }
    Repeater {
        model: card.available ? card.applications.packages : []
        Ui.FieldRow {
            id: row
            required property var modelData
            readonly property var release: modelData.release || null
            readonly property string releaseSummary: !release ? qsTr("%1: no release source configured.").arg(label)
                : !release.version ? (release.error ? qsTr("%1: release check failed.").arg(label) : qsTr("%1: latest release not checked.").arg(label))
                : release.error ? qsTr("%1: last known %2; check failed.").arg(label).arg(release.version)
                : release.stale ? qsTr("%1: last known release %2.").arg(label).arg(release.version)
                : qsTr("%1: latest release %2.").arg(label).arg(release.version)
            objectName: "updateApplication:" + modelData.scope + ":" + modelData.name
            Layout.fillWidth: true
            label: modelData.name
            RowLayout {
                Layout.fillWidth: true
                Ui.ThemeText {
                    objectName: "updateApplicationLocal"
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: row.modelData.version || "—"
                    font.pixelSize: Ui.Theme.formValueSize
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    Accessible.name: qsTr("%1: declared local %2").arg(row.label).arg(row.modelData.version || qsTr("Not reported"))
                    Accessible.description: row.modelData.scope
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    Ui.ThemeText {
                        objectName: "updateApplicationLatest"
                        Layout.fillWidth: true
                        // Only cached upstream evidence can supply this column.
                        text: row.release && row.release.version ? row.release.version : "—"
                        font.pixelSize: Ui.Theme.formValueSize
                        wrapMode: Text.WrapAnywhere
                        textFormat: Text.PlainText
                        Accessible.name: row.releaseSummary
                    }
                    Ui.FeedbackButton {
                        objectName: "updateApplicationStatus"
                        Layout.preferredWidth: Ui.Theme.formActionSize
                        Layout.preferredHeight: Ui.Theme.formActionSize
                        iconSize: Ui.Theme.formActionIconSize
                        icon: row.release && row.release.error ? "warning"
                            : row.release && row.release.version ? (row.release.stale ? "history" : "info") : "help_outline"
                        accessibleName: qsTr("Version status: %1").arg(row.label)
                        Accessible.description: [row.releaseSummary, row.release ? row.release.source : "",
                            row.release && row.release.checked_at ? qsTr("Checked %1").arg(card.controller.timeLabel(row.release.checked_at)) : "",
                            row.release ? row.release.error || "" : ""].filter(Boolean).join(". ")
                        feedback: explanation
                        feedbackText: row.releaseSummary
                        feedbackBrief: qsTr("Application release status")
                    }
                }
            }
        }
    }
}
