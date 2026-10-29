pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import Shelllist.Core as Core

Rectangle {
    id: page
    required property UpdateController controller
    readonly property var applications: controller.overview ? controller.overview.applications : null
    readonly property bool available: !!applications && applications.available
    readonly property string helpText: qsTr("Declared local versions; latest known upstream releases. Refresh only reads.")
    objectName: "updateApplicationsOverview"
    color: Ui.Theme.surface
    radius: Ui.Theme.cardRadius
    Accessible.description: available ? qsTr("%1 of %2 declared packages").arg(applications.packages.length).arg(applications.total) : ""

    // Disclosure belongs to the page, never a recycled row.
    Ui.FeedbackSource {
        id: explanation
        objectName: "updateApplicationExplanation"
        priority: 5
        active: page.controller.uiActive && page.controller.detailsOpen
        onActiveChanged: if (!active) text = ""
    }
    onVisibleChanged: if (!visible) explanation.text = ""
    onApplicationsChanged: { explanation.text = ""; updatePackages(); }
    Component.onCompleted: updatePackages()
    function updatePackages(): void {
        if (!list || !packagesModel) return;
        list.captureAnchor();
        // Multiple installed versions can share a scope/name (e.g. fuse or Qt).
        // Also fence repeated identical records accepted by the wire contract.
        const occurrences = new Map();
        packagesModel.rows = available ? applications.packages.map(pkg => {
            const identity = JSON.stringify([pkg.scope, pkg.name, pkg.version]);
            const occurrence = occurrences.get(identity) || 0;
            occurrences.set(identity, occurrence + 1);
            return {key: JSON.stringify([identity, occurrence]), payload: pkg};
        }) : [];
        Qt.callLater(list.restoreAnchor);
    }
    Connections {
        target: page.controller
        function onNavigationInteracted(): void { list.cancelAnchor(); }
    }

    Ui.DetailListView {
        id: list
        objectName: "updateApplicationsList"
        anchors.fill: parent
        anchors.margins: Ui.Theme.cardPadding
        viewMemory: page.controller.viewMemory
        memoryTab: "applications"
        // Bound creation to the viewport, including at the 512-package limit.
        cacheBuffer: 0
        reuseItems: true
        spacing: Ui.Theme.spacingSm
        model: Core.SerializedListModel { id: packagesModel }
        header: Column {
            width: list.width
            spacing: Ui.Theme.spacingMd
            Ui.SectionHeading {
                width: parent.width
                title: qsTr("Applications")
                helpText: page.helpText
                helpFeedback: explanation
            }
            Ui.ThemeText {
                objectName: "updateApplicationUnavailable"
                width: parent.width
                visible: !page.available
                text: page.applications && page.applications.error ? page.applications.error : qsTr("Application inventory not reported")
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
            Ui.FieldRow {
                width: parent.width
                height: implicitHeight
                visible: page.available
                label: qsTr("Name")
                separatorVisible: false
                RowLayout {
                    Layout.fillWidth: true
                    Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Local"); color: Ui.Theme.mutedText }
                    Ui.ThemeText { Layout.fillWidth: true; Layout.preferredWidth: 1; text: qsTr("Latest"); color: Ui.Theme.mutedText }
                }
            }
        }
        delegate: Ui.FieldRow {
            id: row
            required property var resultData
            readonly property var modelData: JSON.parse(resultData.payload)
            property bool pooled: false
            ListView.onPooled: pooled = true
            ListView.onReused: pooled = false
            // Pooled commands must not remain discoverable in Alt+J.
            visible: !pooled
            readonly property var release: modelData.release || null
            readonly property string releaseSummary: !release ? qsTr("%1: no release source configured.").arg(label)
                : !release.version ? (release.error ? qsTr("%1: release check failed.").arg(label) : qsTr("%1: latest release not checked.").arg(label))
                : release.error ? qsTr("%1: last known %2; check failed.").arg(label).arg(release.version)
                : release.stale ? qsTr("%1: last known release %2.").arg(label).arg(release.version)
                : qsTr("%1: latest release %2.").arg(label).arg(release.version)
            objectName: pooled ? "" : "updateApplication:" + modelData.scope + ":" + modelData.name
            width: list.width
            height: implicitHeight
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
                            row.release && row.release.checked_at ? qsTr("Checked %1").arg(page.controller.timeLabel(row.release.checked_at)) : "",
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
