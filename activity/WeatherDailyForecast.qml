pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

WeatherForecastCard {
    id: forecast
    readonly property var days: (weather.daily || []).slice(0, 7)
    height: days.length > 0 ? 43 + days.length * 43 : 150
    hasData: days.length > 0
    emptyText: qsTr("No daily forecast")
    label: qsTr("Next 7 days")
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
                    text: dayRow.modelData.display?.day || "—"
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                WeatherIcon {
                    anchors.left: parent.left
                    anchors.leftMargin: 59
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    conditionCode: dayRow.modelData.condition_code ?? -1
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
                    text: dayRow.modelData.display?.precipitation || "—"
                    color: Ui.Theme.accent
                    font.pixelSize: Ui.Theme.metadataSize
                }
                Ui.ThemeText {
                    anchors.right: temperatureRange.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.modelData.display?.low || "—"
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
                        x: (dayRow.modelData.display?.low_fraction || 0) * parent.width
                        width: Math.max(8, (dayRow.modelData.display?.span_fraction || 0) * parent.width)
                        height: parent.height
                        radius: height / 2
                        color: Ui.Theme.accent
                    }
                }
                Ui.ThemeText {
                    anchors.left: temperatureRange.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: dayRow.modelData.display?.high || "—"
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }
}
