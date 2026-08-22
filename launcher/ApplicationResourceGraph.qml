import QtQuick
import Shelllist.Ui as Ui

Ui.ChartFrame {
    id: graph

    required property var points
    required property real uiScale
    property string metric: "cpu_percent_of_machine"
    property real minimumMaximum: 0

    readonly property var values: (points || []).map(function (point) {
        const value = Number(point[metric] || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })
    readonly property real maximum: Math.max(minimumMaximum, 1,
        values.reduce(function (current, value) { return Math.max(current, value); }, 0))

    graphHeight: Math.round(82 * uiScale)
    onValuesChanged: chart.requestPaint()
    onMaximumChanged: chart.requestPaint()
    onRepaintRequested: chart.requestPaint()

    Canvas {
        id: chart
        anchors.fill: parent
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
