pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property date now

    readonly property var weather: controller.activity.weather || ({ available: false })

    function numberLabel(value: var, suffix: string): string {
        const number = Number(value);
        return Number.isFinite(number) ? Math.round(number) + suffix : "—";
    }
    function worldTime(clock: var): string {
        const shifted = new Date(now.getTime() + Number(clock.utc_offset_seconds || 0) * 1000);
        return String(shifted.getUTCHours()).padStart(2, "0") + ":"
            + String(shifted.getUTCMinutes()).padStart(2, "0");
    }

    spacing: Ui.Theme.spacingMd

    Rectangle {
        width: parent.width
        height: 180
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.selected
        border.color: Ui.Theme.border

        Row {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingLg

            Column {
                width: parent.width * 0.6
                spacing: 5
                Text {
                    text: String(pane.weather.location || "Local").toUpperCase()
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightBold
                }
                Text {
                    text: Qt.formatTime(pane.now, "HH:mm")
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 54
                    font.weight: Ui.Theme.fontWeightRegular
                }
                Text {
                    text: Qt.formatDate(pane.now, "dddd, d MMMM")
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeBody
                }
            }
            Column {
                width: parent.width * 0.4
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Text {
                    width: parent.width
                    text: pane.numberLabel(pane.weather.temperature_c, "°")
                    color: Ui.Theme.text
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 43
                }
                Text {
                    width: parent.width
                    text: pane.weather.available
                        ? pane.weather.condition || "Current conditions"
                        : pane.weather.error || "Weather unavailable"
                    color: Ui.Theme.mutedText
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
                Text {
                    visible: pane.weather.available
                    width: parent.width
                    text: "H " + pane.numberLabel(pane.weather.high_c, "°")
                        + "  L " + pane.numberLabel(pane.weather.low_c, "°")
                    color: Ui.Theme.mutedText
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 214
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: Ui.Theme.spacingSm
            Text {
                text: "Next 12 hours"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Row {
                id: hourlyRow
                width: parent.width
                height: parent.height - y
                spacing: Ui.Theme.spacingSm
                Repeater {
                    model: (pane.weather.hourly || []).slice(0, 8)
                    delegate: Rectangle {
                        id: hourlyCard
                        required property var modelData
                        width: (hourlyRow.width - hourlyRow.spacing * 7) / 8
                        height: parent.height
                        radius: Ui.Theme.controlRadius
                        color: Ui.Theme.surfaceRaised
                        border.color: Ui.Theme.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 9
                            Text {
                                width: parent.width
                                text: Qt.formatTime(new Date(Number(hourlyCard.modelData.time_unix_ms)), "HH:mm")
                                color: Ui.Theme.mutedText
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                            Text {
                                width: parent.width
                                text: pane.numberLabel(hourlyCard.modelData.temperature_c, "°")
                                color: Ui.Theme.text
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeHeading
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                            Text {
                                width: parent.width
                                text: pane.numberLabel(hourlyCard.modelData.precipitation_probability, "%")
                                color: Ui.Theme.accent
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }
                }
                Text {
                    visible: (pane.weather.hourly || []).length === 0
                    width: parent.width
                    text: "Hourly forecast appears when weather is configured."
                    color: Ui.Theme.mutedText
                    horizontalAlignment: Text.AlignHCenter
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Math.max(190, parent.height - y)
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Row {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: Ui.Theme.spacingMd

            Column {
                width: parent.width * 0.62
                height: parent.height
                spacing: Ui.Theme.spacingSm
                Text {
                    text: "7-day forecast"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Repeater {
                    model: (pane.weather.daily || []).slice(0, 7)
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        height: 27
                        Text {
                            width: parent.width * 0.4
                            text: Qt.formatDate(new Date(Number(parent.modelData.date_unix_ms)), "ddd")
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }
                        Text {
                            width: parent.width * 0.35
                            text: parent.modelData.condition || ""
                            color: Ui.Theme.mutedText
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }
                        Text {
                            width: parent.width * 0.25
                            horizontalAlignment: Text.AlignRight
                            text: pane.numberLabel(parent.modelData.high_c, "°") + "  "
                                + pane.numberLabel(parent.modelData.low_c, "°")
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }
                    }
                }
                Text {
                    visible: (pane.weather.daily || []).length === 0
                    text: "No forecast data"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }

            Rectangle {
                width: 1
                height: parent.height
                color: Ui.Theme.border
            }

            Column {
                width: parent.width - x
                spacing: Ui.Theme.spacingSm
                Text {
                    text: "World clocks"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Repeater {
                    model: pane.controller.activity.world_clocks || []
                    delegate: Row {
                        required property var modelData
                        width: parent.width
                        height: 30
                        Text {
                            width: parent.width * 0.58
                            text: parent.modelData.label || parent.modelData.city
                            color: Ui.Theme.text
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }
                        Text {
                            width: parent.width * 0.42
                            horizontalAlignment: Text.AlignRight
                            text: pane.worldTime(parent.modelData)
                            color: Ui.Theme.mutedText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                        }
                    }
                }
                Text {
                    visible: (pane.controller.activity.world_clocks || []).length === 0
                    width: parent.width
                    text: "No additional clocks configured"
                    color: Ui.Theme.mutedText
                    wrapMode: Text.Wrap
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }
        }
    }
}
