import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Rectangle {
    id: graph

    required property var points
    required property real uiScale
    property string metric: "cpu_percent_of_machine"
    property string label: "CPU"
    property string valueText: ""
    property color lineColor: Ui.Theme.accent
    property real minimumMaximum: 0

    readonly property var values: (points || []).map(function (point) {
        const value = Number(point[metric] || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })
    readonly property real maximum: Math.max(minimumMaximum, 1,
        values.reduce(function (current, value) { return Math.max(current, value); }, 0))

    Layout.fillWidth: true
    Layout.preferredHeight: Math.round(82 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    border.width: 1

    onValuesChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onWidthChanged: chart.requestPaint()
    onHeightChanged: chart.requestPaint()

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.topMargin: 7
        text: graph.label
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 10
        anchors.topMargin: 7
        text: graph.valueText
        color: graph.lineColor
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Canvas {
        id: chart

        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 27
        anchors.bottomMargin: 9
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const values = graph.values;
            if (values.length === 0)
                return;
            const denominator = Math.max(1, values.length - 1);
            context.beginPath();
            values.forEach(function (value, index) {
                const x = index / denominator * width;
                const y = height - Math.min(1, value / graph.maximum) * height;
                if (index === 0)
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
            });
            context.strokeStyle = graph.lineColor;
            context.lineWidth = Math.max(1.5, graph.uiScale * 1.5);
            context.lineJoin = "round";
            context.lineCap = "round";
            context.stroke();
        }
    }
}
