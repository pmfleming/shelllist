pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Item {
    id: graph

    required property var points
    property var forecast: ({ limit: null, target: 100, seconds: 0 })
    property real currentPercentage: -1
    property color lineColor: Ui.Theme.resourceCpu
    property real hoverPosition: -1
    readonly property int graphHeight: 246
    readonly property var series: History.series(points, "percentage", 100, false)
    readonly property var powerSeries: History.series(points, "power_watts", 0, false)
    readonly property var powerAreas: History.powerAreas(powerSeries.segments)
    readonly property real powerMaximum: Math.max(10, Math.ceil(powerSeries.maximum / 10) * 10)
    readonly property real historyFraction: forecast.seconds > 0 ? Math.max(60000, series.activeDurationMs) / (Math.max(60000, series.activeDurationMs) + forecast.seconds * 1000) : 1
    readonly property real historicalPosition: hoverPosition / historyFraction
    readonly property var hoveredSample: hoverPosition >= 0 && historicalPosition <= 1 ? History.nearestSample(series.segments, historicalPosition) : null
    readonly property var hoveredPower: hoverPosition >= 0 && historicalPosition <= 1 ? History.nearestSample(powerSeries.segments, historicalPosition) : null
    readonly property string hoverText: historicalPosition > 1
        ? "Estimated · ~" + Presentation.duration(forecast.seconds) + (forecast.target === 0 ? " to empty" : " to " + forecast.target + "%")
        : (hoveredSample ? new Date(hoveredSample.timestamp_ms).toLocaleString() + " · " + hoveredSample.value + "%" : "No charge sample")
          + (hoveredPower ? "\n" + (hoveredPower.charging ? "+" : "") + hoveredPower.value.toFixed(1) + " W · nearest measurement" : "\nNo power measurement")

    signal hovered(real position)
    onHovered: function (position) { hoverPosition = position; }
    Layout.fillWidth: true
    Layout.preferredHeight: graphHeight
    implicitHeight: graphHeight
    onSeriesChanged: chart.requestPaint()
    onPowerSeriesChanged: chart.requestPaint()
    onPowerAreasChanged: chart.requestPaint()
    onForecastChanged: chart.requestPaint()
    onCurrentPercentageChanged: chart.requestPaint()
    onHistoryFractionChanged: chart.requestPaint()
    onHoverPositionChanged: chart.requestPaint()
    onLineColorChanged: chart.requestPaint()

    Repeater {
        model: [100, 50, 0]
        delegate: Ui.ThemeText {
            required property int modelData
            x: 0
            y: chart.y + 3 + (1 - modelData / 100) * (chart.height - 6) - height / 2
            text: modelData + "%"
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
    Repeater {
        model: [1, 0.5, 0]
        delegate: Ui.ThemeText {
            required property real modelData
            anchors.right: parent.right
            y: chart.y + 3 + (1 - modelData) * (chart.height - 6) - height / 2
            text: (graph.powerMaximum * modelData).toFixed(0)
            color: Ui.Theme.resourcePower
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }

    Canvas {
        id: chart
        objectName: "batteryHistoryPlot"
        anchors.fill: parent
        anchors.leftMargin: 38
        anchors.rightMargin: 28
        anchors.topMargin: 26
        anchors.bottomMargin: 32
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const context = getContext("2d");
            context.reset();
            const inset = 3;
            const plotWidth = Math.max(0, width - 2 * inset);
            const plotHeight = Math.max(0, height - 2 * inset);
            const nowX = inset + graph.historyFraction * plotWidth;
            function y(value) { return inset + (1 - value / 100) * plotHeight; }
            function x(value) { return inset + value * graph.historyFraction * plotWidth; }
            if (graph.historyFraction < 1) {
                context.fillStyle = Ui.Theme.withAlpha(graph.lineColor, 0.06);
                context.fillRect(nowX, inset, plotWidth * (1 - graph.historyFraction), plotHeight);
            }
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.2);
            context.lineWidth = 1;
            context.beginPath();
            [0, 0.5, 1].forEach(function (fraction) {
                context.moveTo(inset, inset + fraction * plotHeight);
                context.lineTo(inset + plotWidth, inset + fraction * plotHeight);
            });
            [0, 0.25, 0.5, 0.75, 1].forEach(function (fraction) {
                context.moveTo(inset + fraction * plotWidth, inset);
                context.lineTo(inset + fraction * plotWidth, inset + plotHeight);
            });
            context.stroke();

            // Connect historical wattage measurements, keeping sleep/missing
            // data separate and colouring each direction independently.
            context.lineWidth = 1.5;
            context.lineJoin = "round";
            context.lineCap = "round";
            graph.powerAreas.forEach(function (area) {
                const color = area.charging ? Ui.Theme.active : Ui.Theme.resourcePower;
                context.strokeStyle = color;
                context.fillStyle = color;
                const points = area.points.map(function (point) {
                    return { x: x(point.x), y: inset + (1 - point.value / graph.powerMaximum) * plotHeight };
                });
                Ui.ChartDrawing.series(context, [points], inset + plotHeight, Ui.Theme.withAlpha(color, 0.28), true);
            });

            // Explicit observation boundaries (sleep/restart/clock gaps), not
            // charging-mode changes. Downtime occupies no observed-time width.
            context.strokeStyle = Ui.Theme.resourceCpu;
            context.lineWidth = 1;
            graph.series.breaks.forEach(function (position) {
                Ui.ChartDrawing.dashed(context, x(position), inset, x(position), inset + plotHeight, 4, 4);
            });

            context.strokeStyle = graph.lineColor;
            context.fillStyle = graph.lineColor;
            context.lineWidth = 2;
            context.lineJoin = "round";
            context.lineCap = "round";
            const fill = context.createLinearGradient(0, inset, 0, inset + plotHeight);
            fill.addColorStop(0, Ui.Theme.withAlpha(graph.lineColor, 0.15));
            fill.addColorStop(1, Ui.Theme.withAlpha(graph.lineColor, 0.015));
            const segments = graph.series.segments.map(function (segment) {
                return segment.map(function (point) { return { x: x(point.x), y: y(point.value) }; });
            });
            Ui.ChartDrawing.series(context, segments, inset + plotHeight, fill, true);
            if (graph.currentPercentage >= 0 && graph.currentPercentage <= 100) {
                context.beginPath();
                context.arc(nowX, y(graph.currentPercentage), 3, 0, Math.PI * 2);
                context.fill();
                context.strokeStyle = Ui.Theme.text;
                context.stroke();
            }
            if (graph.forecast.seconds > 0) {
                context.strokeStyle = graph.lineColor;
                Ui.ChartDrawing.dashed(context, nowX, y(graph.forecast.percentage), inset + plotWidth, y(graph.forecast.target), 5, 4);
                context.beginPath();
                context.arc(inset + plotWidth, y(graph.forecast.target), 3, 0, Math.PI * 2);
                context.stroke();
            }
            context.lineWidth = 1;
            context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.55);
            if (graph.forecast.limit !== null && graph.forecast.limit !== undefined)
                Ui.ChartDrawing.dashed(context, inset, y(graph.forecast.limit), inset + plotWidth, y(graph.forecast.limit), 3, 5);
            Ui.ChartDrawing.dashed(context, nowX, inset, nowX, inset + plotHeight, 3, 4);
            if (graph.hoverPosition >= 0) {
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.text, 0.6);
                const hoverX = inset + graph.hoverPosition * plotWidth;
                Ui.ChartDrawing.dashed(context, hoverX, inset, hoverX, inset + plotHeight, 2, 3);
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onPositionChanged: function (mouse) {
                graph.hovered(Math.max(0, Math.min(1, (mouse.x - 3) / Math.max(1, width - 6))));
            }
            onExited: graph.hovered(-1)
            Controls.ToolTip.visible: containsMouse
            Controls.ToolTip.text: graph.hoverText
        }
    }

    Ui.ThemeText {
        objectName: "chargeLimitLabel"
        visible: graph.forecast.limit !== null && graph.forecast.limit !== undefined
        anchors.right: chart.right
        y: Math.max(0, chart.y + 3 + (1 - Number(graph.forecast.limit) / 100) * (chart.height - 6) - implicitHeight - 2)
        text: graph.forecast.limit + "% limit"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        objectName: "historyEmptyLabel"
        anchors.centerIn: chart
        width: chart.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: graph.series.segments.length === 0 && graph.forecast.seconds <= 0
        text: graph.currentPercentage >= 0 ? "Collecting history" : "No battery measurements"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        id: pastLabel
        anchors.left: chart.left
        anchors.bottom: parent.bottom
        width: Math.max(0, graph.historyFraction * chart.width - nowLabel.implicitWidth - 8)
        elide: Text.ElideRight
        text: graph.series.activeDurationMs > 0 ? "−" + Presentation.duration(graph.series.activeDurationMs / 1000) : ""
        color: Ui.Theme.subtleText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        id: nowLabel
        objectName: "historyNowLabel"
        x: Math.max(chart.x, Math.min(chart.x + chart.width - implicitWidth, chart.x + 3 + graph.historyFraction * (chart.width - 6) - implicitWidth / 2))
        anchors.bottom: parent.bottom
        text: "Now"
        color: Ui.Theme.text
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Ui.ThemeText {
        objectName: "historyForecastLabel"
        visible: graph.forecast.seconds > 0 && x > nowLabel.x + nowLabel.width + 8
        anchors.right: chart.right
        anchors.bottom: parent.bottom
        text: "+" + Presentation.duration(graph.forecast.seconds)
        color: Ui.Theme.subtleText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        visible: graph.forecast.seconds > 0 && (1 - graph.historyFraction) * chart.width > implicitWidth + 8
        anchors.right: chart.right
        anchors.top: parent.top
        text: "Estimated"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
