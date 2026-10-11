pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryHistory.js" as History
import "BatteryPresentation.js" as Presentation

Item {
    id: graph

    required property var points
    property var forecast: ({limit: null, target: 100, seconds: 0})
    property real currentPercentage: -1
    property color lineColor: Ui.Theme.batteryCharge
    readonly property color chargingColor: Ui.Theme.batteryCharging
    readonly property color dischargingColor: Ui.Theme.batteryDischarging
    readonly property color guideColor: Ui.Theme.mutedText
    property real hoverPosition: -1
    property bool inspecting: false
    property real inspectionPosition: 1
    // Battery-owned plot geometry: two equal-height tracks, with one shared
    // gutter/time axis. Text uses Theme roles and never becomes a field stop.
    readonly property int graphHeight: 310
    readonly property real axisInset: Math.max(38, tickMetrics.advanceWidth("+" + powerMaximum.toFixed(0)) + Ui.Theme.spacingSm)
    readonly property var series: History.series(points, "percentage", 100, false)
    readonly property var powerSeries: History.series(points, "power_watts", 0, false)
    readonly property real powerMaximum: Math.max(10, Math.ceil(powerSeries.maximum / 10) * 10)
    readonly property real historyFraction: forecast.seconds > 0 ? Math.max(60000, series.activeDurationMs) / (Math.max(60000, series.activeDurationMs) + forecast.seconds * 1000) : 1
    readonly property real cursorPosition: inspecting ? inspectionPosition : hoverPosition
    readonly property real historicalPosition: cursorPosition / historyFraction
    readonly property var inspectedSample: historicalPosition >= 0 && historicalPosition <= 1 ? History.nearestSample(series.segments, historicalPosition) : null
    readonly property var inspectedPower: historicalPosition >= 0 && historicalPosition <= 1 ? History.nearestSample(powerSeries.segments, historicalPosition) : null
    readonly property string inspectionReading: (inspectedSample ? inspectedSample.value + "%" : qsTr("No charge sample"))
        + (inspectedPower ? " · " + inspectedPower.value.toFixed(1) + " W " + (inspectedPower.value === 0 ? qsTr("· no flow") : inspectedPower.charging ? qsTr("in") : qsTr("out")) : qsTr(" · No power measurement"))
    readonly property string inspectionText: historicalPosition > 1
        ? qsTr("Estimated · ~%1 %2").arg(Presentation.duration(forecast.seconds)).arg(forecast.target === 0 ? qsTr("to empty") : qsTr("to %1%").arg(forecast.target))
        : (inspectedSample ? new Date(inspectedSample.timestamp_ms).toLocaleString() + " · " : "")
            + inspectionReading + (inspectedPower ? qsTr(" · nearest measurement") : "")
    readonly property string inspectionSummary: historicalPosition > 1 ? inspectionText
        : (inspectedSample ? new Date(inspectedSample.timestamp_ms).toLocaleString(Qt.locale(), Locale.ShortFormat) + " · " : "") + inspectionReading

    Layout.fillWidth: true
    Layout.preferredHeight: graphHeight
    implicitHeight: graphHeight
    activeFocusOnTab: false // Pointer entry only; Range remains the editable field.
    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Battery history")
    Accessible.description: cursorPosition >= 0 ? inspectionText : qsTr("Charge in percent above battery power in watts. Charging is above zero; discharging is below. Time excludes suspended intervals.")

    function inspect(position: real): void {
        inspectionPosition = Math.max(0, Math.min(1, position));
        inspecting = true;
    }
    function repaint(): void {
        chart.requestPaint();
        powerChart.requestPaint();
    }
    function paintCursor(context: var, plotWidth: real, plotHeight: real): void {
        if (cursorPosition < 0)
            return;
        context.lineWidth = 1;
        context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.text, 0.6);
        const cursorX = 3 + cursorPosition * Math.max(0, plotWidth - 6);
        Ui.ChartDrawing.dashed(context, cursorX, 3, cursorX, plotHeight - 3, 2, 3);
    }
    onSeriesChanged: repaint()
    onPowerSeriesChanged: repaint()
    onForecastChanged: repaint()
    onCurrentPercentageChanged: repaint()
    onHistoryFractionChanged: repaint()
    onCursorPositionChanged: repaint()
    onLineColorChanged: repaint()
    onChargingColorChanged: repaint()
    onDischargingColorChanged: repaint()
    onGuideColorChanged: repaint()

    // Explicit pointer inspection retains its native arrows and Escape exit.
    // There is no command or Tab route into the chart.
    Keys.onShortcutOverride: function (event) {
        if (graph.inspecting && event.key === Qt.Key_Escape && event.modifiers === Qt.NoModifier)
            event.accepted = true;
    }
    Keys.onPressed: function (event) {
        event.accepted = false;
        if (event.modifiers !== Qt.NoModifier || !graph.inspecting)
            return;
        if ([Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter].includes(event.key)) {
            graph.inspecting = false;
        } else if ([Qt.Key_Left, Qt.Key_Right].includes(event.key)) {
            graph.inspect(graph.inspectionPosition + (event.key === Qt.Key_Right ? 0.025 : -0.025));
        } else if ([Qt.Key_Home, Qt.Key_End].includes(event.key)) {
            graph.inspect(event.key === Qt.Key_Home ? 0 : 1);
        } else {
            return;
        }
        event.accepted = true;
    }
    FontMetrics {
        id: tickMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.FocusRing {
        active: graph.activeFocus && graph.inspecting
    }
    component PlotPointer: MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPositionChanged: function (mouse) {
            graph.hoverPosition = Math.max(0, Math.min(1, (mouse.x - 3) / Math.max(1, width - 6)));
        }
        onExited: graph.hoverPosition = -1
        onClicked: function (mouse) {
            graph.forceActiveFocus();
            graph.inspect((mouse.x - 3) / Math.max(1, width - 6));
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            objectName: "batteryChargeTrackLabel"
            Layout.fillWidth: true
            text: qsTr("Charge · %")
            font.pixelSize: Ui.Theme.fontSizeBody
        }
        Ui.ThemeText {
            text: graph.currentPercentage >= 0 && graph.currentPercentage <= 100 ? qsTr("%1% now").arg(Math.round(graph.currentPercentage)) : qsTr("Unavailable")
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.metadataSize
        }
    }
    Repeater {
        model: [100, 50, 0]
        delegate: Ui.ThemeText {
            required property int modelData
            width: graph.axisInset - Ui.Theme.spacingSm
            horizontalAlignment: Text.AlignRight
            y: chart.y + 3 + (1 - modelData / 100) * (chart.height - 6) - height / 2
            text: modelData
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
    Canvas {
        id: chart
        objectName: "batteryHistoryPlot"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: graph.axisInset
        anchors.rightMargin: Ui.Theme.spacingXs
        anchors.topMargin: Ui.Theme.spacingXxl
        height: 100
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

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
                context.fillStyle = Ui.Theme.withAlpha(graph.lineColor, 0.04);
                context.fillRect(nowX, inset, plotWidth * (1 - graph.historyFraction), plotHeight);
            }
            context.strokeStyle = Ui.Theme.withAlpha(graph.guideColor, 0.12);
            context.lineWidth = 1;
            context.beginPath();
            [0, 0.5, 1].forEach(function (fraction) {
                context.moveTo(inset, inset + fraction * plotHeight);
                context.lineTo(inset + plotWidth, inset + fraction * plotHeight);
            });
            context.stroke();
            context.strokeStyle = graph.lineColor;
            context.fillStyle = graph.lineColor;
            context.lineWidth = 2;
            context.lineJoin = "round";
            context.lineCap = "round";
            const segments = graph.series.segments.map(segment => segment.map(point => ({x: x(point.x), y: y(point.value)})));
            Ui.ChartDrawing.series(context, segments, inset + plotHeight, Ui.Theme.withAlpha(graph.lineColor, 0.08), true);
            // A dotted charge change, never an observed line across downtime.
            context.lineWidth = 1;
            graph.series.breaks.forEach(function (gap) {
                Ui.ChartDrawing.dashed(context, x(gap.from.x), y(gap.from.value), x(gap.to.x), y(gap.to.value), 2, 4);
            });
            if (graph.currentPercentage >= 0 && graph.currentPercentage <= 100) {
                context.beginPath();
                context.arc(nowX, y(graph.currentPercentage), 3, 0, Math.PI * 2);
                context.fill();
            }
            const forecastPercentage = History.nonnegative(graph.forecast.percentage) ? graph.forecast.percentage : graph.currentPercentage;
            if (graph.forecast.seconds > 0 && forecastPercentage >= 0 && forecastPercentage <= 100) {
                context.lineWidth = 2;
                Ui.ChartDrawing.dashed(context, nowX, y(forecastPercentage), inset + plotWidth, y(graph.forecast.target), 5, 4);
                context.beginPath();
                context.arc(inset + plotWidth, y(graph.forecast.target), 3, 0, Math.PI * 2);
                context.stroke();
            }
            context.lineWidth = 1;
            context.strokeStyle = Ui.Theme.withAlpha(graph.guideColor, 0.45);
            if (graph.forecast.limit !== null && graph.forecast.limit !== undefined)
                Ui.ChartDrawing.dashed(context, inset, y(graph.forecast.limit), inset + plotWidth, y(graph.forecast.limit), 3, 5);
            if (graph.historyFraction < 1)
                Ui.ChartDrawing.dashed(context, nowX, inset, nowX, inset + plotHeight, 3, 4);
            graph.paintCursor(context, width, height);
        }
        PlotPointer {}
    }
    Ui.ThemeText {
        objectName: "chargeLimitLabel"
        visible: graph.forecast.limit !== null && graph.forecast.limit !== undefined
        anchors.right: chart.right
        y: Math.max(0, chart.y + 3 + (1 - Number(graph.forecast.limit) / 100) * (chart.height - 6) - implicitHeight - 2)
        text: qsTr("%1% limit").arg(graph.forecast.limit)
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ContentState {
        objectName: "historyEmptyLabel"
        anchors.fill: chart
        visible: graph.series.segments.length === 0 && graph.forecast.seconds <= 0
        compact: true
        icon: graph.currentPercentage >= 0 ? "history" : "battery_full"
        kind: graph.currentPercentage >= 0 ? "collecting" : "empty"
        text: graph.currentPercentage >= 0 ? qsTr("Collecting history") : qsTr("No battery measurements")
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        y: chart.y + chart.height + Ui.Theme.spacingMd
        height: 1
        color: Ui.Theme.withAlpha(graph.guideColor, 0.12)
    }
    RowLayout {
        id: powerHeading
        anchors.left: parent.left
        anchors.right: parent.right
        y: chart.y + chart.height + Ui.Theme.spacingXl
        spacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            objectName: "batteryPowerTrackLabel"
            Layout.fillWidth: true
            text: qsTr("Battery power")
            font.pixelSize: Ui.Theme.fontSizeBody
        }
        Ui.ThemeText {
            text: qsTr("Watts · in / out")
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.metadataSize
        }
    }
    Repeater {
        model: [1, 0, -1]
        delegate: Ui.ThemeText {
            required property real modelData
            width: graph.axisInset - Ui.Theme.spacingSm
            horizontalAlignment: Text.AlignRight
            y: powerChart.y + powerChart.height / 2 - modelData * (powerChart.height / 2 - 3) - height / 2
            text: (modelData > 0 ? "+" : modelData < 0 ? "−" : "") + Math.abs(graph.powerMaximum * modelData).toFixed(0)
            color: Ui.Theme.subtleText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
    Canvas {
        id: powerChart
        objectName: "batteryPowerPlot"
        anchors.left: chart.left
        anchors.right: chart.right
        anchors.top: powerHeading.bottom
        anchors.topMargin: Ui.Theme.spacingSm
        height: 100
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        function barRect(sample: var): var {
            const x = 3 + sample.x * graph.historyFraction * Math.max(0, width - 6);
            const magnitude = sample.value / graph.powerMaximum * (height / 2 - 3);
            return {x: x - 2, y: sample.charging ? height / 2 - magnitude : height / 2, width: 4, height: magnitude};
        }
        onPaint: {
            const context = getContext("2d");
            context.reset();
            const baseline = height / 2;
            context.strokeStyle = Ui.Theme.withAlpha(graph.guideColor, 0.2);
            context.lineWidth = 1;
            context.beginPath();
            context.moveTo(3, baseline);
            context.lineTo(width - 3, baseline);
            context.stroke();
            // Paint measurements, not interpolated durations: isolated readings
            // remain bars; absent/suspended samples never become zero or bridges.
            graph.powerSeries.segments.forEach(segment => segment.forEach(sample => {
                const bar = powerChart.barRect(sample);
                context.fillStyle = sample.value === 0 ? graph.guideColor : sample.charging ? graph.chargingColor : graph.dischargingColor;
                context.fillRect(bar.x, sample.value === 0 ? baseline - 0.5 : bar.y, bar.width, Math.max(1, bar.height));
            }));
            graph.paintCursor(context, width, height);
        }
        PlotPointer {}
    }
    Ui.ThemeText {
        anchors.left: powerChart.left
        anchors.leftMargin: Ui.Theme.spacingXs
        y: powerChart.y - implicitHeight / 2 + 3
        text: qsTr("in")
        color: graph.chargingColor
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ThemeText {
        anchors.left: powerChart.left
        anchors.leftMargin: Ui.Theme.spacingXs
        y: powerChart.y + powerChart.height - implicitHeight / 2 - 3
        text: qsTr("out")
        color: graph.dischargingColor
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
    Ui.ContentState {
        objectName: "powerHistoryEmptyLabel"
        anchors.fill: powerChart
        visible: graph.powerSeries.segments.length === 0
        compact: true
        icon: "bolt"
        kind: "empty"
        text: qsTr("No power measurements")
    }
    Ui.ThemeText {
        anchors.left: chart.left
        anchors.bottom: parent.bottom
        width: Math.max(0, graph.historyFraction * chart.width - nowLabel.implicitWidth - Ui.Theme.spacingSm)
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
        text: qsTr("Now")
        color: Ui.Theme.text
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }
    Ui.ThemeText {
        objectName: "historyForecastLabel"
        visible: graph.forecast.seconds > 0 && x > nowLabel.x + nowLabel.width + Ui.Theme.spacingSm
        anchors.right: chart.right
        anchors.bottom: parent.bottom
        text: qsTr("+%1 estimated").arg(Presentation.duration(graph.forecast.seconds))
        color: Ui.Theme.subtleText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
