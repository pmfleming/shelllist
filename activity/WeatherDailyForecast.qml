pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

WeatherForecastCard {
    id: forecast
    readonly property var days: (weather.daily || []).slice(0, 7)
    readonly property real minimum: Visuals.collectionMinimum(days, "low_c")
    readonly property real maximum: Visuals.collectionMaximum(days, "high_c")
    height: 43 + forecast.days.length * 43
    label: "7D"
    labelTopMargin: 10

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: 36

        Repeater {
            model: forecast.days
            delegate: Item {
                id: dayRow
                required property var modelData
                width: parent.width
                height: 43

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Ui.Theme.border
                    opacity: 0.6
                }
                Ui.ThemeText {
                    anchors.left: parent.left
                    anchors.leftMargin: Ui.Theme.spacingMd
                    anchors.verticalCenter: parent.verticalCenter
                    width: 43
                    text: Visuals.localDay(dayRow.modelData.date_unix_ms, Number(forecast.weather.utc_offset_seconds || 0))
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                WeatherIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 59
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    conditionCode: Visuals.conditionCode(dayRow.modelData.condition_code)
                    daytime: true
                    description: dayRow.modelData.condition || ""
                }
                Image {
                    anchors.left: parent.left
                    anchors.leftMargin: 105
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    source: "assets/weather/raindrop.svg"
                    fillMode: Image.PreserveAspectFit
                }
                Ui.ThemeText {
                    anchors.left: parent.left
                    anchors.leftMargin: 123
                    anchors.verticalCenter: parent.verticalCenter
                    width: 39
                    text: Visuals.numberLabel(dayRow.modelData.precipitation_probability, "%")
                    color: Ui.Theme.accent
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
                Ui.ThemeText {
                    anchors.right: temperatureRange.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Visuals.numberLabel(dayRow.modelData.low_c, "°")
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
                Item {
                    id: temperatureRange
                    anchors.right: parent.right
                    anchors.rightMargin: 55
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(170, parent.width * 0.37)
                    height: 8

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Ui.Theme.surfaceRaised
                        border.color: Ui.Theme.border
                    }
                    Rectangle {
                        readonly property real span: Math.max(1, forecast.maximum - forecast.minimum)
                        x: (Number(dayRow.modelData.low_c || 0) - forecast.minimum) / span * parent.width
                        width: Math.max(8, (Number(dayRow.modelData.high_c || 0) - Number(dayRow.modelData.low_c || 0)) / span * parent.width)
                        height: parent.height
                        radius: height / 2
                        color: Ui.Theme.accent
                    }
                }
                Ui.ThemeText {
                    anchors.left: temperatureRange.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: Visuals.numberLabel(dayRow.modelData.high_c, "°")
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }
}
