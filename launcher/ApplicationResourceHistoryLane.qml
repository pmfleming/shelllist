pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

RowLayout {
    id: lane
    required property var points
    required property var descriptor
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    required property real maximum
    required property string chartStyle
    property real uiScale: 1
    property bool loading: false
    property bool active: true
    readonly property bool hasHistory: Resources.historySegments(points, descriptor.metric, rangeStartMilliseconds, rangeEndMilliseconds).length > 0
    spacing: Math.round(10 * uiScale)
    Accessible.role: Accessible.StaticText
    Accessible.name: descriptor.label + ". " + qsTr("Scale 0 to %1. %2").arg(Resources.formatted(maximum, descriptor.kind)).arg(descriptor.detailText)

    ApplicationResourceGlyph {
        glyph: lane.descriptor.icon
        color: lane.descriptor.color
        uiScale: lane.uiScale
        Layout.preferredWidth: Math.round(25 * lane.uiScale)
        Layout.alignment: Qt.AlignTop
        Layout.topMargin: Math.round(5 * lane.uiScale)
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        ApplicationResourcePlot {
            objectName: "resourcePlot_" + lane.descriptor.metric
            Layout.fillWidth: true
            implicitHeight: Math.round((lane.chartStyle === "steps" ? 96 : 80) * lane.uiScale)
            visible: !lane.loading && lane.hasHistory
            points: lane.points
            series: [lane.descriptor]
            chartStyle: lane.chartStyle
            maximum: lane.maximum
            rangeStartMilliseconds: lane.rangeStartMilliseconds
            rangeEndMilliseconds: lane.rangeEndMilliseconds
            uiScale: lane.uiScale
        }
        Ui.ContentState {
            objectName: "resourceContentState_" + lane.descriptor.metric
            Layout.fillWidth: true
            visible: lane.loading || !lane.hasHistory
            compact: true
            active: lane.active
            icon: lane.descriptor.icon
            kind: lane.loading ? "loading" : "empty"
            text: lane.loading ? qsTr("Reading resource history…") : qsTr("%1: no retained history").arg(lane.descriptor.label)
            uiScale: lane.uiScale
        }
    }
}
