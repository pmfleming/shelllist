import QtQuick
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Ui.ChartFrame {
    id: graph

    required property var points
    property string metric: "percentage"
    property real minimumMaximum: 0
    property bool positiveOnly: false

    readonly property var series: History.series(points, metric, minimumMaximum, positiveOnly)
    readonly property string maximumText: metric === "time_to_full_seconds"
        ? Presentation.duration(series.maximum) : series.maximum + "%"

    graphHeight: 112
    onSeriesChanged: chart.requestPaint()
    onRepaintRequested: chart.requestPaint()

    Text {
        id: maximumLabel
        anchors.left: parent.left
        anchors.top: parent.top
        text: graph.maximumText
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: "0"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Canvas {
        id: chart
        objectName: "batteryHistoryPlot"
        anchors.fill: parent
        anchors.leftMargin: Math.max(32, maximumLabel.implicitWidth + 8)
        // Leave room for the stroke and isolated samples at 0%, 100%, and
        // both ends of the active-time axis; the canvas clips at its bounds.
        anchors.rightMargin: 3
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const inset = 2;
            const plotWidth = Math.max(0, width - 2 * inset);
            const plotHeight = Math.max(0, height - 2 * inset);
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.2);
            context.lineWidth = 1;
            context.beginPath();
            [0, 0.5, 1].forEach(function (fraction) {
                const y = inset + fraction * plotHeight;
                context.moveTo(inset, y);
                context.lineTo(inset + plotWidth, y);
            });
            context.stroke();
            context.strokeStyle = graph.lineColor;
            context.fillStyle = graph.lineColor;
            context.lineWidth = 1.5;
            context.lineJoin = "round";
            context.lineCap = "round";
            graph.series.segments.forEach(function (segment) {
                context.beginPath();
                segment.forEach(function (point, index) {
                    const x = inset + point.x * plotWidth;
                    const y = inset + (1 - point.value / graph.series.maximum) * plotHeight;
                    if (segment.length === 1)
                        context.arc(x, y, 2, 0, Math.PI * 2);
                    else if (index === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                });
                if (segment.length === 1)
                    context.fill();
                else
                    context.stroke();
            });
        }
    }

    Text {
        anchors.centerIn: chart
        visible: graph.series.segments.length === 0
        text: !graph.series.hasActiveTimeline ? "Collecting active-time samples"
            : (graph.metric === "time_to_full_seconds"
                ? "No charging estimates" : "No charge samples")
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
