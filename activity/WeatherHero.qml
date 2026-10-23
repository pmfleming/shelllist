pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: hero
    required property var weather
    property bool updating: false
    property bool active: true
    readonly property bool hasReading: weather.temperature_c !== undefined && weather.temperature_c !== null && Number.isFinite(Number(weather.temperature_c))
    readonly property var display: weather.display || ({})
    readonly property var heroColors: Object.prototype.hasOwnProperty.call(WeatherVisuals.heroColors, display.palette) ? WeatherVisuals.heroColors[display.palette] : WeatherVisuals.heroColors.clear
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
            text: String(hero.weather.location || "—")
            elide: Text.ElideRight
            color: Ui.Theme.weatherHeroText
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Ui.ThemeText {
            id: updated
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: Number(hero.weather.updated_unix_ms || 0) > 0 ? "↻ " + (hero.display.updated || "—") : ""
            color: Ui.Theme.weatherHeroMutedText
            font.pixelSize: Ui.Theme.metadataSize
        }
    }

    Ui.ContentState {
        objectName: "weatherContentState"
        anchors.left: header.left
        anchors.right: header.right
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        visible: !hero.hasReading
        compact: true
        active: hero.active
        icon: "cloud"
        kind: hero.weather.error ? "unavailable" : hero.updating ? "loading" : "empty"
        text: hero.weather.error || (hero.updating ? qsTr("Updating forecast…") : qsTr("No forecast available"))
    }

    TextMetrics {
        id: candidateTemperature
        font.family: Ui.Theme.fontFamily
        font.pixelSize: hero.compact ? Ui.Theme.heroWeatherCompactSize : Ui.Theme.heroWeatherSize
        text: hero.display.temperature || "—"
    }

    Item {
        visible: hero.hasReading
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
            conditionCode: hero.weather.condition_code ?? -1
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
                objectName: "weatherCurrentTemperature"
                anchors.right: parent.right
                text: hero.display.temperature || "—"
                color: Ui.Theme.weatherHeroTemperature
                // Increase the hero only when the unchanged content region fits.
                // Keep room for condition text and the existing high/low line.
                font.pixelSize: candidateTemperature.advanceWidth <= Math.max(0, temperature.parent.width - conditionIcon.width - 2 * Ui.Theme.spacingMd - 5 * Ui.Theme.fontSizeHeading)
                    ? candidateTemperature.font.pixelSize
                    : hero.compact ? Ui.Theme.heroWeatherCompactFallbackSize : Ui.Theme.heroWeatherFallbackSize
            }
            Ui.ThemeText {
                id: dailyRange
                anchors.right: parent.right
                text: "↑ " + (hero.display.high || "—") + "   ↓ " + (hero.display.low || "—")
                color: Ui.Theme.weatherHeroSecondaryText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }

    Row {
        id: metrics
        objectName: "weatherHeroMetrics"
        visible: hero.hasReading
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
                    value: hero.display.apparent_temperature || "—"
                },
                {
                    icon: "raindrop",
                    label: qsTr("Rain chance"),
                    value: hero.display.precipitation || "—"
                },
                {
                    icon: "wind",
                    label: qsTr("Wind"),
                    value: hero.display.wind || "—"
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
                        font.pixelSize: Ui.Theme.metadataSize
                    }
                    Ui.ThemeText {
                        width: parent.width
                        text: heroMetric.modelData.value
                        fontSizeMode: Text.HorizontalFit
                        minimumPixelSize: Ui.Theme.metadataSize
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
