pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: card
    required property var weather
    required property date now
    signal requested(string section)
    width: parent.width
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.selected
    border.color: Ui.Theme.border
    clip: true

    Item {
        anchors.fill: parent
        anchors.margins: Ui.Theme.spacingSm

        Ui.ActionArea {
            id: weatherHeader
            accessibleName: qsTr("Open Time and Weather")
            onClicked: card.requested("weather")
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.right: parent.right
            height: 18

            Ui.ThemeText {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Local time · Weather")
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Ui.ThemeText {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "↗"
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.fontSizeHeading
            }
        }

        Item {
            anchors.left: parent.left
            anchors.top: weatherHeader.bottom
            anchors.topMargin: 2
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Ui.ActionArea {
                id: timeSummary
                accessibleName: qsTr("Open city times")
                onClicked: card.requested("time")
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Math.round(parent.width * 0.38)

                Column {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Ui.ThemeText {
                        text: Qt.formatTime(card.now, "HH:mm")
                        font.pixelSize: 26
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        text: Qt.formatDate(card.now, "ddd, d MMM").toUpperCase()
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }

            Ui.ActionArea {
                accessibleName: qsTr("Open city weather")
                onClicked: card.requested("weather")
                anchors.left: timeSummary.right
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Item {
                    id: weatherVisual
                    anchors.left: parent.left
                    // Match the temperature block, not the taller card body.
                    anchors.top: temperatureSummary.top
                    anchors.bottom: temperatureSummary.bottom
                    width: 54

                    WeatherIcon {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 34
                        height: width
                        conditionCode: Visuals.conditionCode(card.weather.condition_code)
                        daytime: card.weather.is_day !== false
                        description: card.weather.condition || ""
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 2

                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 11
                            height: width
                            source: "assets/weather/raindrop.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Ui.ThemeText {
                            text: card.weather.available ? Math.round(Number(card.weather.precipitation_probability)) + "%" : "—"
                            color: Ui.Theme.mutedText
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }

                Column {
                    id: temperatureSummary
                    anchors.left: weatherVisual.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 76
                    spacing: 0

                    Ui.ThemeText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: (card.weather.available ? Visuals.numberLabel(card.weather.temperature_c, "°") : "—")
                        font.pixelSize: 24
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: card.weather.available ? Math.round(Number(card.weather.high_c)) + "°  " + Math.round(Number(card.weather.low_c)) + "°" : "—"
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                }

                Column {
                    anchors.left: temperatureSummary.right
                    anchors.leftMargin: Ui.Theme.spacingSm
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Row {
                        spacing: 3
                        Image {
                            width: 15
                            height: 15
                            source: "assets/weather/thermometer.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Ui.ThemeText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Feels " + (card.weather.available ? Math.round(Number(card.weather.apparent_temperature_c)) + "°" : "—")
                            color: Ui.Theme.mutedText
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                    Row {
                        spacing: 3
                        Image {
                            width: 15
                            height: 15
                            source: "assets/weather/wind.svg"
                            fillMode: Image.PreserveAspectFit
                        }
                        Ui.ThemeText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: card.weather.available ? Math.round(Number(card.weather.wind_speed_kmh)) + " km/h" : "—"
                            color: Ui.Theme.mutedText
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                    }
                }
            }
        }
    }
}
