pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

WeatherForecastCard {
    id: hourlyCard
    readonly property var points: (weather.display?.hour_indices || []).map(index => weather.hourly[index])
    onPointsChanged: hourlyChart.requestPaint()
    // Pixel geometry only; native projection owns the normalized data range.
    function hourY(point: var): real {
        return 143 - (point.display?.temperature_fraction || 0) * 66;
    }
    height: 232
    label: qsTr("Next 12 hours")
    hasData: points.length > 0
    emptyText: qsTr("No hourly forecast")
    labelTopMargin: 8

    Canvas {
        id: hourlyChart
        anchors.fill: parent
        anchors.margins: 10

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);
            const points = hourlyCard.points;
            if (points.length < 2)
                return;
            const slot = width / points.length;

            context.fillStyle = String(Ui.Theme.weatherPrecipitation);
            for (let index = 0; index < points.length; ++index) {
                const probability = Number(points[index].precipitation_probability || 0);
                const barHeight = probability / 100 * 28;
                context.fillRect(index * slot + slot * 0.31, 183 - barHeight, slot * 0.38, barHeight);
            }

            const vertices = points.map((point, index) => ({
                x: index * slot + slot / 2, y: hourlyCard.hourY(point)
            }));
            context.strokeStyle = String(Ui.Theme.accent);
            context.lineWidth = 2.5;
            Ui.ChartDrawing.segment(context, vertices, 0, null, false);

            context.fillStyle = String(Ui.Theme.accent);
            for (const point of vertices) {
                context.beginPath();
                context.arc(point.x, point.y, 3.5, 0, Math.PI * 2);
                context.fill();
            }
        }
    }

    Repeater {
        model: hourlyCard.points
        delegate: Item {
            id: hourPoint
            required property var modelData
            required property int index
            width: hourlyCard.width / Math.max(1, hourlyCard.points.length)
            height: hourlyCard.height
            x: index * width

            WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: 38
                height: 38
                conditionCode: hourPoint.modelData.condition_code ?? -1
                daytime: hourPoint.modelData.is_day !== false
                description: hourPoint.modelData.condition || ""
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: hourlyCard.hourY(hourPoint.modelData) - 20
                text: hourPoint.modelData.display?.temperature || "—"
                font.pixelSize: Ui.Theme.metadataSize
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 184
                text: Number(hourPoint.modelData.precipitation_probability || 0) > 0 ? (hourPoint.modelData.display?.precipitation || "—") : ""
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.metadataSize
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                text: hourPoint.modelData.display?.time || "—"
                color: Ui.Theme.subtleText
                font.pixelSize: Ui.Theme.metadataSize
            }
        }
    }

    Ui.ThemeText {
        visible: hourlyCard.points.length < 2
        anchors.centerIn: parent
        text: "—"
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeDisplay
    }
}
