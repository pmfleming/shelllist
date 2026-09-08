pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Row {
    id: visualMetrics
    required property var weather
    width: parent.width
    height: 106
    spacing: Ui.Theme.spacingSm

    Repeater {
        model: [
            {
                icon: "humidity",
                value: Visuals.numberLabel(visualMetrics.weather.humidity_percent, "%")
            },
            {
                icon: "wind",
                value: Visuals.windCompass(visualMetrics.weather.wind_direction_degrees) + "  " + Visuals.numberLabel(visualMetrics.weather.wind_gust_kmh, " km/h")
            },
            {
                icon: "sunrise",
                value: Visuals.weatherTime(visualMetrics.weather.sunrise_unix_ms, visualMetrics.weather)
            },
            {
                icon: "sunset",
                value: Visuals.weatherTime(visualMetrics.weather.sunset_unix_ms, visualMetrics.weather)
            }
        ]
        delegate: Rectangle {
            id: visualMetric
            required property var modelData
            width: (visualMetrics.width - visualMetrics.spacing * 3) / 4
            height: parent.height
            radius: Ui.Theme.panelRadius
            color: Ui.Theme.surface
            border.color: Ui.Theme.border

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 10
                width: 48
                height: 48
                source: "assets/weather/" + visualMetric.modelData.icon + ".svg"
                fillMode: Image.PreserveAspectFit
            }
            Ui.ThemeText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                text: visualMetric.modelData.value
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }
    }
}
