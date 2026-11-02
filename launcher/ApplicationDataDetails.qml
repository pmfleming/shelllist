pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// Passive application metadata shares one card on the Settings page.
Ui.DetailColumnCard {
    id: card
    required property ApplicationController controller
    required property var application
    readonly property var points: controller.historyTargetId === application.id ? controller.resourceHistory || [] : []
    readonly property var snapshot: application.running ? application : points.length ? points[points.length - 1] : null
    readonly property var software: application.software || null
    objectName: "applicationDataDetails"
    title: qsTr("App data")
    helpText: (software ? Ui.SoftwarePresentation.summary(software) + "\n\n" : "")
        + qsTr("Identified app data only. Installation and shared dependencies are not measured. Referenced files may overlap and are not added. Temporary data is not necessarily safe to delete. Stopped applications use retained observations when available.")

    Ui.DetailGrid {
        objectName: "applicationDataVersions"
        Layout.fillWidth: true
        visible: card.software !== null
        entries: card.software ? [
            {label: qsTr("Local version"), value: Ui.SoftwarePresentation.local(card.software)},
            {label: qsTr("Latest version"), value: Ui.SoftwarePresentation.latest(card.software)}
        ] : []
    }
    Ui.FieldRow {
        visible: card.software !== null
        label: qsTr("Source")
        Ui.ThemeText {
            objectName: "applicationDataSource"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: card.software ? Ui.SoftwarePresentation.details(card.software) || qsTr("No package version reported") : ""
            font.pixelSize: Ui.Theme.fontSizeLabel
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            Accessible.name: qsTr("Source: %1").arg(text)
        }
    }
    Ui.DetailField {
        objectName: "applicationDataTotal"
        Layout.fillWidth: true
        label: qsTr("Identified app data")
        value: card.reading("disk_space_total_bytes")
        valueBold: true
    }
    Ui.DetailGrid {
        objectName: "applicationDataStorage"
        Layout.fillWidth: true
        entries: [
            {label: qsTr("Persistent"), value: card.reading("disk_space_permanent_bytes")},
            {label: qsTr("Temporary"), value: card.reading("disk_space_temporary_bytes")}
        ]
    }
    function reading(metric: string): string {
        const available = application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(snapshot, metric);
        return available ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : snapshot[metric], "bytes") : qsTr("Unavailable");
    }
}
