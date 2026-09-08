pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Ui.ChartFrame {
    id: graph

    required property var points
    property bool energy: false
    property var forecast: ({ limit: null, seconds: 0 })
    property real currentPercentage: -1
    property real historyFraction: 1
    property real axisWidth: 48
    property real hoverPosition: -1
    property bool showTimeAxis: false

    readonly property var series: History.series(points, "percentage", 100, false)
    readonly property var energySeries: History.energySeries(points)
    readonly property real maximum: energy ? energySeries.maximum : 100
    readonly property string maximumText: energy ? maximum.toFixed(1) : "100%"
    readonly property real scaleWidth: maximumLabel.implicitWidth + 8

    signal hovered(real position)

    // These are tracks within one card, not two nested cards.
    color: "transparent"
    border.width: 0
    graphHeight: energy ? 126 : 146
    onSeriesChanged: chart.requestPaint()
    onEnergySeriesChanged: chart.requestPaint()
    onForecastChanged: chart.requestPaint()
    onCurrentPercentageChanged: chart.requestPaint()
    onHistoryFractionChanged: chart.requestPaint()
    onHoverPositionChanged: chart.requestPaint()
    onRepaintRequested: chart.requestPaint()

    Ui.ThemeText {
        id: maximumLabel
        anchors.left: parent.left
        anchors.top: parent.top
        text: graph.maximumText
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        anchors.left: parent.left
        y: chart.y + chart.height - implicitHeight
        text: "0"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Canvas {
        id: chart
        objectName: "batteryHistoryPlot"
        anchors.fill: parent
        anchors.leftMargin: graph.axisWidth
        anchors.rightMargin: 3
        anchors.topMargin: 3
        anchors.bottomMargin: graph.showTimeAxis ? 23 : 3
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const inset = 2;
            const plotWidth = Math.max(0, width - 2 * inset);
            const plotHeight = Math.max(0, height - 2 * inset);
            const nowX = inset + graph.historyFraction * plotWidth;
            function y(value) { return inset + (1 - value / graph.maximum) * plotHeight; }
            function x(value) { return inset + value * graph.historyFraction * plotWidth; }
            function dashed(x0, y0, x1, y1, dash, gap) {
                const length = Math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
                context.beginPath();
                for (let offset = 0; offset < length; offset += dash + gap) {
                    const end = Math.min(length, offset + dash);
                    context.moveTo(x0 + (x1 - x0) * offset / length, y0 + (y1 - y0) * offset / length);
                    context.lineTo(x0 + (x1 - x0) * end / length, y0 + (y1 - y0) * end / length);
                }
                context.stroke();
            }
            if (graph.historyFraction < 1) {
                context.fillStyle = Ui.Theme.withAlpha(Ui.Theme.accent, 0.04);
                context.fillRect(nowX, inset, plotWidth * (1 - graph.historyFraction), plotHeight);
            }
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.2);
            context.lineWidth = 1;
            context.beginPath();
            [0, 0.5, 1].forEach(function (fraction) {
                const row = inset + fraction * plotHeight;
                context.moveTo(inset, row);
                context.lineTo(inset + plotWidth, row);
            });
            context.stroke();
            if (!graph.energy && graph.forecast.limit !== null) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.5);
                dashed(inset, y(graph.forecast.limit), inset + plotWidth, y(graph.forecast.limit), 4, 5);
            }
            context.strokeStyle = graph.lineColor;
            context.fillStyle = graph.energy ? Ui.Theme.withAlpha(graph.lineColor, 0.45) : graph.lineColor;
            context.lineWidth = 1.5;
            context.lineJoin = "round";
            context.lineCap = "round";
            if (graph.energy) {
                graph.energySeries.bars.forEach(function (bar) {
                    const left = x(bar.x0);
                    const barWidth = x(bar.x1) - left;
                    const gap = Math.min(2, barWidth * 0.2);
                    context.fillRect(left + gap / 2, y(bar.value), Math.max(0, barWidth - gap),
                        plotHeight * bar.value / graph.maximum);
                });
            } else {
                graph.series.segments.forEach(function (segment) {
                    context.beginPath();
                    segment.forEach(function (point, index) {
                        if (segment.length === 1)
                            context.arc(x(point.x), y(point.value), 2, 0, Math.PI * 2);
                        else if (index === 0)
                            context.moveTo(x(point.x), y(point.value));
                        else
                            context.lineTo(x(point.x), y(point.value));
                    });
                    if (segment.length === 1)
                        context.fill();
                    else
                        context.stroke();
                });
                if (graph.currentPercentage >= 0 && graph.currentPercentage <= 100) {
                    context.beginPath();
                    context.arc(nowX, y(graph.currentPercentage), 2, 0, Math.PI * 2);
                    context.fill();
                }
                if (graph.forecast.seconds > 0) {
                    dashed(nowX, y(graph.forecast.percentage), inset + plotWidth, y(graph.forecast.target), 2, 4);
                    context.beginPath();
                    context.arc(inset + plotWidth, y(graph.forecast.target), 2, 0, Math.PI * 2);
                    context.stroke();
                }
            }
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.5);
            context.lineWidth = 1;
            context.beginPath();
            context.moveTo(nowX, inset);
            context.lineTo(nowX, inset + plotHeight);
            context.stroke();
            if (graph.hoverPosition >= 0) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.text, 0.6);
                dashed(inset + graph.hoverPosition * plotWidth, inset,
                    inset + graph.hoverPosition * plotWidth, inset + plotHeight, 2, 3);
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: function (mouse) {
                graph.hovered(Math.max(0, Math.min(1, (mouse.x - 2) / Math.max(1, width - 4))));
            }
            onExited: graph.hovered(-1)
        }
    }

    Ui.ThemeText {
        objectName: "chargeLimitLabel"
        visible: !graph.energy && graph.forecast.limit !== null
        anchors.right: chart.right
        y: Math.max(0, chart.y + 2 + (1 - Number(graph.forecast.limit) / 100)
            * (chart.height - 4) - implicitHeight - 2)
        text: graph.forecast.limit + "% limit"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        anchors.centerIn: chart
        visible: graph.energy ? graph.energySeries.bars.length === 0 : graph.series.segments.length === 0
        text: graph.energy ? "No observed discharge energy"
            : (graph.currentPercentage >= 0 ? "Collecting charge history" : "No charge samples")
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        visible: graph.showTimeAxis
        anchors.left: chart.left
        anchors.bottom: parent.bottom
        width: Math.max(0, graph.historyFraction * chart.width - 40)
        elide: Text.ElideRight
        text: graph.series.activeDurationMs > 0
            ? "−" + Presentation.duration(graph.series.activeDurationMs / 1000) + " observed" : ""
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        objectName: "historyNowLabel"
        visible: graph.showTimeAxis
        x: chart.x + 2 + graph.historyFraction * (chart.width - 4) - implicitWidth
        anchors.bottom: parent.bottom
        text: "Now"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        visible: graph.showTimeAxis && (1 - graph.historyFraction) * chart.width > implicitWidth + 8
        anchors.right: chart.right
        anchors.bottom: parent.bottom
        text: "Estimated"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
