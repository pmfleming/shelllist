pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Item {
    id: graph

    required property var points
    property bool energy: false
    property var forecast: ({
            limit: null,
            seconds: 0
        })
    property real currentPercentage: -1
    property real historyFraction: 1
    property string label: ""
    property string valueText: ""
    property string referenceText: ""
    property color lineColor: Ui.Theme.resourceCpu
    property int graphHeight: 64 + (showTimeAxis ? 28 : 0)
    property real axisWidth: 138
    property real hoverPosition: -1
    property bool showTimeAxis: false

    readonly property var series: History.series(points, "percentage", 100, false)
    readonly property var energySeries: History.energySeries(points)
    readonly property real maximum: energy ? energySeries.maximum : 100

    signal hovered(real position)

    Layout.fillWidth: true
    Layout.preferredHeight: graphHeight
    implicitHeight: graphHeight
    onSeriesChanged: chart.requestPaint()
    onEnergySeriesChanged: chart.requestPaint()
    onForecastChanged: chart.requestPaint()
    onCurrentPercentageChanged: chart.requestPaint()
    onHistoryFractionChanged: chart.requestPaint()
    onHoverPositionChanged: chart.requestPaint()
    onLineColorChanged: chart.requestPaint()
    onEnergyChanged: chart.requestPaint()

    Ui.ThemeText {
        anchors.left: parent.left
        y: 4
        width: graph.axisWidth - 10
        text: graph.label
        color: Ui.Theme.mutedText
        elide: Text.ElideRight
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Ui.ThemeText {
        objectName: "batteryHistoryValue"
        anchors.left: parent.left
        y: 20
        width: graph.axisWidth - 10
        text: graph.valueText
        color: graph.lineColor
        elide: Text.ElideRight
        font.weight: Ui.Theme.fontWeightBold
    }

    Ui.ThemeText {
        anchors.left: parent.left
        y: 39
        width: graph.axisWidth - 10
        text: graph.referenceText
        color: Ui.Theme.subtleText
        elide: Text.ElideRight
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Canvas {
        id: chart
        objectName: "batteryHistoryPlot"
        anchors.fill: parent
        anchors.leftMargin: graph.axisWidth
        anchors.topMargin: 4
        anchors.bottomMargin: 6 + (graph.showTimeAxis ? 28 : 0)
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
            function y(value) {
                return inset + (1 - value / graph.maximum) * plotHeight;
            }
            function x(value) {
                return inset + value * graph.historyFraction * plotWidth;
            }
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
                context.fillStyle = Ui.Theme.withAlpha(graph.lineColor, 0.04);
                context.fillRect(nowX, inset, plotWidth * (1 - graph.historyFraction), plotHeight);
            }
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.border, 0.26);
            context.lineWidth = 1;
            context.beginPath();
            [0.25, 0.5, 0.75].forEach(function (fraction) {
                const column = inset + fraction * plotWidth;
                context.moveTo(column, inset);
                context.lineTo(column, inset + plotHeight);
            });
            context.stroke();
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.22);
            context.beginPath();
            context.moveTo(inset, inset + plotHeight);
            context.lineTo(inset + plotWidth, inset + plotHeight);
            context.stroke();
            if (!graph.energy && graph.forecast.limit !== null) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.5);
                dashed(inset, y(graph.forecast.limit), inset + plotWidth, y(graph.forecast.limit), 4, 5);
            }
            context.strokeStyle = graph.lineColor;
            context.fillStyle = graph.energy ? Ui.Theme.withAlpha(graph.lineColor, 0.45) : graph.lineColor;
            context.lineWidth = 1.75;
            context.lineJoin = "round";
            context.lineCap = "round";
            if (graph.energy) {
                graph.energySeries.bars.forEach(function (bar) {
                    const left = x(bar.x0);
                    const barWidth = x(bar.x1) - left;
                    const gap = Math.min(2, barWidth * 0.2);
                    context.fillRect(left + gap / 2, y(bar.value), Math.max(0, barWidth - gap), plotHeight * bar.value / graph.maximum);
                });
            } else {
                graph.series.segments.forEach(function (segment) {
                    // Fill each continuous segment separately: sleep/offline gaps
                    // must never look like measured charge.
                    if (segment.length > 1) {
                        context.beginPath();
                        context.moveTo(x(segment[0].x), inset + plotHeight);
                        segment.forEach(function (point) {
                            context.lineTo(x(point.x), y(point.value));
                        });
                        context.lineTo(x(segment[segment.length - 1].x), inset + plotHeight);
                        context.closePath();
                        const fill = context.createLinearGradient(0, inset, 0, inset + plotHeight);
                        fill.addColorStop(0, Ui.Theme.withAlpha(graph.lineColor, 0.2));
                        fill.addColorStop(1, Ui.Theme.withAlpha(graph.lineColor, 0.025));
                        context.fillStyle = fill;
                        context.fill();
                    }
                    context.fillStyle = graph.lineColor;
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
            // Only mark "now" inside the plot when a forecast follows it.
            if (graph.historyFraction < 1) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.3);
                context.lineWidth = 1;
                dashed(nowX, inset, nowX, inset + plotHeight, 2, 3);
            }
            if (graph.hoverPosition >= 0) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.text, 0.6);
                dashed(inset + graph.hoverPosition * plotWidth, inset, inset + graph.hoverPosition * plotWidth, inset + plotHeight, 2, 3);
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
        y: Math.max(0, chart.y + 2 + (1 - Number(graph.forecast.limit) / 100) * (chart.height - 4) - implicitHeight - 2)
        text: graph.forecast.limit + "% limit"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        anchors.centerIn: chart
        width: chart.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: graph.energy ? graph.energySeries.bars.length === 0 : graph.series.segments.length === 0
        text: graph.energy ? "No observed discharge energy" : (graph.currentPercentage >= 0 ? "Collecting charge history" : "No charge samples")
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Ui.ThemeText {
        visible: graph.showTimeAxis
        anchors.left: chart.left
        anchors.bottom: parent.bottom
        width: Math.max(0, graph.historyFraction * chart.width - 40)
        elide: Text.ElideRight
        text: graph.series.activeDurationMs > 0 ? "−" + Presentation.duration(graph.series.activeDurationMs / 1000) + " observed" : ""
        color: Ui.Theme.subtleText
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
        font.weight: Ui.Theme.fontWeightDemiBold
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
