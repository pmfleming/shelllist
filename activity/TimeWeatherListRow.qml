import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Ui.ResultRow {
    id: row

    required property var resultData
    required property double nowMs
    readonly property var city: resultData.payload || ({})
    readonly property var weather: city.weather || ({})
    readonly property bool hasWeather: !!city.has_weather && !!weather.available

    accessibleName: city.label + ". "
        + (hasWeather ? weather.condition + ", " + temperature(weather.temperature_c)
            + ", " + percentage(weather.precipitation_probability) + " chance of rain"
            : "No weather")
        + ". " + localTime()

    function temperature(value: var): string {
        const number = Number(value);
        return Number.isFinite(number) ? Math.round(number) + "°" : "—";
    }
    function percentage(value: var): string {
        const number = Number(value);
        return Number.isFinite(number) ? Math.round(number) + "%" : "—";
    }
    function localTime(): string {
        return Visuals.localTime(nowMs, Number(city.utc_offset_seconds || 0));
    }

    Ui.GlyphLabel {
        Layout.preferredWidth: row.scaled(24)
        Layout.fillHeight: true
        glyph: row.city.home ? "󰋜" : "󰍎"
        color: row.city.home ? Ui.Theme.accent : Ui.Theme.mutedText
        font.pixelSize: Math.max(Ui.Theme.iconSize, row.scaled(Ui.Theme.iconSizeLarge))
    }

    Ui.ResultLabel {
        Layout.fillWidth: true
        title: row.city.label || "Location"
        subtitle: row.city.timezone || "Timezone unavailable"
        titleWeight: row.city.home ? Ui.Theme.fontWeightDemiBold
            : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }

    Item {
        Layout.preferredWidth: row.scaled(104)
        Layout.preferredHeight: row.scaled(48)
        Layout.alignment: Qt.AlignVCenter

        Column {
            visible: row.hasWeather
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: row.scaled(40)
            spacing: 0

            WeatherIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: row.scaled(34)
                height: width
                conditionCode: Number(row.weather.condition_code || 0)
                daytime: row.weather.is_day !== false
                description: row.weather.condition || ""
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: row.scaled(2)

                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: row.scaled(11)
                    height: width
                    source: Qt.resolvedUrl("assets/weather/raindrop.svg")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
                Text {
                    text: row.percentage(row.weather.precipitation_probability)
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
                }
            }
        }

        Text {
            visible: !row.hasWeather
            anchors.centerIn: parent
            text: "—"
            color: Ui.Theme.subtleText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
        }

        Column {
            visible: row.hasWeather
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.right: parent.right
                text: row.temperature(row.weather.temperature_c)
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Text {
                anchors.right: parent.right
                text: row.temperature(row.weather.high_c) + " "
                    + row.temperature(row.weather.low_c)
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
            }
        }
    }

    Column {
        Layout.preferredWidth: row.scaled(68)
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Text {
            anchors.right: parent.right
            text: row.localTime()
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Text {
            anchors.right: parent.right
            text: row.city.abbreviation || Visuals.utcOffset(row.city.utc_offset_seconds)
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
        }
    }
}
