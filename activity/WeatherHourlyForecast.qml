pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

WeatherForecastCard {
    id: hourlyCard
    required property date now
    readonly property var points: Visuals.futureHours(weather.hourly || [], now.getTime())
    readonly property real minimum: Visuals.collectionMinimum(points, "temperature_c")
    readonly property real maximum: Visuals.collectionMaximum(points, "temperature_c")
    onPointsChanged: hourlyChart.requestPaint()
    onMinimumChanged: hourlyChart.requestPaint()
    onMaximumChanged: hourlyChart.requestPaint()
    function hourY(value: var): real {
        return Visuals.temperatureY(value, minimum, maximum);
    }
    height: 232
    label: "12H"
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

            context.beginPath();
            for (let index = 0; index < points.length; ++index) {
                const x = index * slot + slot / 2;
                const y = hourlyCard.hourY(points[index].temperature_c);
                if (index === 0)
                    context.moveTo(x, y);
                else
                    context.lineTo(x, y);
            }
            context.strokeStyle = String(Ui.Theme.accent);
            context.lineWidth = 2.5;
            context.stroke();

            context.fillStyle = String(Ui.Theme.accent);
            for (let index = 0; index < points.length; ++index) {
                const x = index * slot + slot / 2;
                const y = hourlyCard.hourY(points[index].temperature_c);
                context.beginPath();
                context.arc(x, y, 3.5, 0, Math.PI * 2);
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
                conditionCode: Visuals.conditionCode(hourPoint.modelData.condition_code)
                daytime: hourPoint.modelData.is_day !== false
                description: hourPoint.modelData.condition || ""
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: hourlyCard.hourY(hourPoint.modelData.temperature_c) - 20
                text: Visuals.numberLabel(hourPoint.modelData.temperature_c, "°")
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 184
                text: Number(hourPoint.modelData.precipitation_probability || 0) > 0 ? Visuals.numberLabel(hourPoint.modelData.precipitation_probability, "%") : ""
                color: Ui.Theme.accent
                font.pixelSize: 9
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 7
                text: Visuals.weatherTime(hourPoint.modelData.time_unix_ms, hourlyCard.weather)
                color: Ui.Theme.subtleText
                font.pixelSize: Ui.Theme.fontSizeCaption
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
