pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: hero
    required property var weather
    readonly property var heroColors: Visuals.heroColors(Visuals.conditionCode(weather.condition_code), weather.is_day !== false)
    readonly property bool compact: width < 420
    width: parent.width
    height: 192
    radius: Ui.Theme.panelRadius
    border.color: Ui.Theme.weatherHeroBorder

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop {
            position: 0
            color: hero.heroColors[0]
        }
        GradientStop {
            position: 1
            color: hero.heroColors[1]
        }
    }

    Item {
        id: header
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Ui.Theme.spacingLg
        anchors.topMargin: Ui.Theme.spacingMd
        height: Ui.Theme.fontSizeLabel + 6

        Ui.ThemeText {
            objectName: "weatherHeroLocation"
            anchors.left: parent.left
            anchors.right: updated.left
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.verticalCenter: parent.verticalCenter
            text: String(hero.weather.location || "—").toUpperCase()
            elide: Text.ElideRight
            color: Ui.Theme.weatherHeroText
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Ui.ThemeText {
            id: updated
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Number(hero.weather.updated_unix_ms || 0) > 0 ? "↻ " + Visuals.weatherTime(hero.weather.updated_unix_ms, hero.weather) : ""
            color: Ui.Theme.weatherHeroMutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }

    Item {
        id: summary
        anchors.left: header.left
        anchors.right: header.right
        anchors.top: header.bottom
        anchors.bottom: metrics.top
        anchors.bottomMargin: Ui.Theme.spacingSm

        WeatherIcon {
            id: conditionIcon
            objectName: "weatherHeroIcon"
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: hero.compact ? 72 : 112
            height: Math.min(width, parent.height)
            conditionCode: Visuals.conditionCode(hero.weather.condition_code)
            daytime: hero.weather.is_day !== false
            description: hero.weather.condition || ""
        }

        Ui.ThemeText {
            objectName: "weatherHeroCondition"
            anchors.left: conditionIcon.right
            anchors.right: temperature.left
            anchors.margins: Ui.Theme.spacingMd
            anchors.verticalCenter: parent.verticalCenter
            text: hero.weather.condition || qsTr("Weather unavailable")
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Ui.Theme.weatherHeroText
            font.pixelSize: hero.compact ? Ui.Theme.fontSizeHeading : Ui.Theme.fontSizeTitle
            font.weight: Ui.Theme.fontWeightMedium
        }

        Column {
            id: temperature
            objectName: "weatherHeroTemperature"
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(currentTemperature.implicitWidth, dailyRange.implicitWidth)
            spacing: 0

            Ui.ThemeText {
                id: currentTemperature
                anchors.right: parent.right
                text: Visuals.numberLabel(hero.weather.temperature_c, "°")
                color: Ui.Theme.weatherHeroTemperature
                font.pixelSize: hero.compact ? 48 : 56
            }
            Ui.ThemeText {
                id: dailyRange
                anchors.right: parent.right
                text: "↑ " + Visuals.numberLabel(hero.weather.high_c, "°") + "   ↓ " + Visuals.numberLabel(hero.weather.low_c, "°")
                color: Ui.Theme.weatherHeroSecondaryText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }

    Row {
        id: metrics
        objectName: "weatherHeroMetrics"
        anchors.left: header.left
        anchors.right: header.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Ui.Theme.spacingSm
        height: 48

        Repeater {
            model: [
                {
                    icon: "thermometer",
                    label: qsTr("Feels like"),
                    value: Visuals.numberLabel(hero.weather.apparent_temperature_c, "°")
                },
                {
                    icon: "raindrop",
                    label: qsTr("Rain chance"),
                    value: Visuals.numberLabel(hero.weather.precipitation_probability, "%")
                },
                {
                    icon: "wind",
                    label: qsTr("Wind"),
                    value: Visuals.windCompass(hero.weather.wind_direction_degrees) + " " + Visuals.numberLabel(hero.weather.wind_speed_kmh, " km/h")
                }
            ]
            delegate: Item {
                id: heroMetric
                required property var modelData
                required property int index
                objectName: "weatherHeroMetric" + index
                width: metrics.width / 3
                height: metrics.height

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Ui.Theme.weatherHeroBorder
                }
                Rectangle {
                    visible: heroMetric.index > 0
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Ui.Theme.spacingMd
                    anchors.bottomMargin: Ui.Theme.spacingXs
                    width: 1
                    color: Ui.Theme.weatherHeroBorder
                }
                Image {
                    id: metricIcon
                    anchors.left: parent.left
                    anchors.leftMargin: heroMetric.index > 0 ? Ui.Theme.spacingMd : 0
                    anchors.verticalCenter: metricText.verticalCenter
                    width: hero.compact ? 16 : 21
                    height: width
                    source: "assets/weather/" + heroMetric.modelData.icon + ".svg"
                    fillMode: Image.PreserveAspectFit
                }
                Column {
                    id: metricText
                    anchors.left: metricIcon.right
                    anchors.leftMargin: Ui.Theme.spacingXs
                    anchors.right: parent.right
                    anchors.rightMargin: Ui.Theme.spacingXs
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 3
                    spacing: 2

                    Ui.ThemeText {
                        width: parent.width
                        text: heroMetric.modelData.label
                        elide: Text.ElideRight
                        color: Ui.Theme.weatherHeroMutedText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                    Ui.ThemeText {
                        width: parent.width
                        text: heroMetric.modelData.value
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: 10
                        elide: Text.ElideRight
                        color: Ui.Theme.weatherHeroMetricText
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }
}
