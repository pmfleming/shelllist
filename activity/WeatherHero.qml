pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: hero
    required property var weather
    required property date now
    readonly property var heroColors: Visuals.heroColors(
        Visuals.conditionCode(weather.condition_code), weather.is_day !== false)
    width: parent.width
    height: 192
    radius: Ui.Theme.panelRadius
    border.color: Ui.Theme.weatherHeroBorder

    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: hero.heroColors[0] }
        GradientStop { position: 1; color: hero.heroColors[1] }
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Ui.Theme.spacingLg
        anchors.topMargin: Ui.Theme.spacingMd
        text: String(hero.weather.location || "—").toUpperCase()
        color: Ui.Theme.weatherHeroText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeLabel
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Ui.Theme.spacingLg
        anchors.topMargin: 39
        text: Visuals.weatherTime(hero.now.getTime(), hero.weather)
        color: Ui.Theme.weatherHeroSecondaryText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Ui.Theme.spacingMd
        anchors.topMargin: Ui.Theme.spacingSm
        text: Number(hero.weather.updated_unix_ms || 0) > 0
            ? "↻ " + Visuals.weatherTime(hero.weather.updated_unix_ms, hero.weather) : ""
        color: Ui.Theme.weatherHeroMutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    WeatherIcon {
        anchors.left: parent.left
        anchors.leftMargin: Math.max(130, parent.width * 0.25)
        anchors.verticalCenter: parent.verticalCenter
        width: 145
        height: 145
        conditionCode: Visuals.conditionCode(hero.weather.condition_code)
        daytime: hero.weather.is_day !== false
        description: hero.weather.condition || ""
    }

    Column {
        anchors.right: parent.right
        anchors.rightMargin: Ui.Theme.spacingLg
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
            anchors.right: parent.right
            text: Visuals.numberLabel(hero.weather.temperature_c, "°")
            color: Ui.Theme.weatherHeroTemperature
            font.family: Ui.Theme.fontFamily
            font.pixelSize: 66
            font.weight: Ui.Theme.fontWeightRegular
        }
        Text {
            anchors.right: parent.right
            text: Visuals.numberLabel(hero.weather.high_c, "°") + "  "
                + Visuals.numberLabel(hero.weather.low_c, "°")
            color: Ui.Theme.weatherHeroSecondaryText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Ui.Theme.spacingLg
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Ui.Theme.spacingSm
        spacing: Ui.Theme.spacingLg

        Repeater {
            model: [
                { icon: "thermometer", value: Visuals.numberLabel(
                    hero.weather.apparent_temperature_c, "°") },
                { icon: "raindrop", value: Visuals.numberLabel(
                    hero.weather.precipitation_probability, "%") },
                { icon: "wind", value: Visuals.windCompass(
                    hero.weather.wind_direction_degrees) + "  "
                    + Visuals.numberLabel(hero.weather.wind_speed_kmh, " km/h") }
            ]
            delegate: Row {
                id: heroMetric
                required property var modelData
                spacing: 4
                Image {
                    width: 21
                    height: 21
                    source: "assets/weather/" + heroMetric.modelData.icon + ".svg"
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: heroMetric.modelData.value
                    color: Ui.Theme.weatherHeroMetricText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }
}
