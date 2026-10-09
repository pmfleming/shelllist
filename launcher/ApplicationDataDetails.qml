pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

// Storage attribution is application context, not a power/energy reading.
Ui.DetailCard {
    required property ApplicationController controller
    required property var application
    readonly property var points: controller.historyTargetId === application.id ? controller.resourceHistory || [] : []
    readonly property var snapshot: application.running ? application : points.length ? points[points.length - 1] : null
    objectName: "applicationDataDetails"
    title: qsTr("App data")
    helpText: qsTr("Identified app data only. Installation and shared dependencies are not measured. Referenced files may overlap and are not added. Temporary data is not necessarily safe to delete. Stopped applications use retained observations when available.")
    entries: [
        {label: qsTr("Identified app data"), value: reading("disk_space_total_bytes")},
        {label: qsTr("Persistent"), value: reading("disk_space_permanent_bytes")},
        {label: qsTr("Temporary"), value: reading("disk_space_temporary_bytes")}
    ]
    function reading(metric: string): string {
        const available = application.running ? Resources.currentMetricAvailable(application, metric) : Resources.historicalMetricAvailable(snapshot, metric);
        return available ? Resources.formatted(application.running ? Resources.currentValue(application, metric) : snapshot[metric], "bytes") : qsTr("Unavailable");
    }
}
