import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var city: resultData.payload || ({})
    readonly property bool clockAvailable: WeatherVisuals.hasLocationClock(city)
    readonly property var display: weather.display || ({})
    readonly property var weather: city.weather || ({})
    readonly property bool hasWeather: !!city.has_weather && !!weather.available

    objectName: "timeWeatherLocation::" + String(city.id || "")
    accessibleName: city.label + (city.home ? qsTr(". Home") : "") + (city.current && !city.home ? qsTr(". Current location") : "") + ". " + WeatherVisuals.locationSubtitle(city) + ". " + (hasWeather ? weather.condition + ", " + (display.temperature || "—") + ", " + (display.precipitation || "—") + " chance of rain" : "No weather") + ". " + (city.clock_display?.time || "—")

    leadingIcon: city.home ? "home" : city.current ? "my_location" : "location_on"
    leadingIconColor: city.home ? Ui.Theme.accent : Ui.Theme.mutedText

    Ui.ResultLabel {
        Layout.fillWidth: true
        title: row.city.label || "Location"
        subtitle: WeatherVisuals.locationSubtitle(row.city)
        titleWeight: row.city.home ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
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
            spacing: 1

            // Keep the artwork from pushing the rain caption below the other captions.
            Item {
                width: parent.width
                height: currentTemperature.height

                WeatherIcon {
                    anchors.centerIn: parent
                    width: row.scaled(28)
                    height: width
                    conditionCode: row.weather.condition_code ?? -1
                    daytime: row.weather.is_day !== false
                    description: row.weather.condition || ""
                }
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                height: temperatureRange.height
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
                Ui.ThemeText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.display.precipitation || "—"
                    color: Ui.Theme.mutedText
                    font.pixelSize: Ui.Theme.metadataSize
                }
            }
        }

        Ui.ThemeText {
            visible: !row.hasWeather
            anchors.centerIn: parent
            text: "—"
            color: Ui.Theme.subtleText
            font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
        }

        Column {
            visible: row.hasWeather
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: row.scaled(54)
            spacing: 1

            Ui.ThemeText {
                id: currentTemperature
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: row.display.temperature || "—"
                font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                id: temperatureRange
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: (row.display.high || "—") + " " + (row.display.low || "—")
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.metadataSize
            }
        }
    }

    Column {
        Layout.preferredWidth: row.scaled(68)
        Layout.alignment: Qt.AlignVCenter
        spacing: 1

        Ui.ThemeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: row.city.clock_display?.time || "—"
            font.pixelSize: row.scaled(Ui.Theme.fontSizeHeading)
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Ui.ThemeText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: row.clockAvailable ? row.city.abbreviation || row.city.clock_display?.offset : "—"
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.metadataSize
        }
    }
}
