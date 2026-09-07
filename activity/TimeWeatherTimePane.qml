pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Ui.DetailFlickable {
    id: pane

    required property var city
    required property date now

    readonly property var weather: city.weather || ({})
    readonly property int offsetSeconds: Number(city.utc_offset_seconds || 0)
    readonly property double sunrise: Number(weather.sunrise_unix_ms || 0)
    readonly property double sunset: Number(weather.sunset_unix_ms || 0)
    readonly property bool hasSunTimes: sunrise > 0 && sunset > sunrise
    readonly property double solarNoon: hasSunTimes ? sunrise + (sunset - sunrise) / 2 : 0
    readonly property real sunProgress: hasSunTimes
        ? Math.max(0, Math.min(1, (now.getTime() - sunrise) / (sunset - sunrise))) : 0
    readonly property var moon: Visuals.moonPhase(now.getTime())

    function time(value: var): string {
        return Number(value || 0) > 0 ? Visuals.localTime(value, offsetSeconds) : "—";
    }

    onSunProgressChanged: sunCanvas.requestPaint()
    onWidthChanged: sunCanvas.requestPaint()

    Rectangle {
        width: parent.width
        height: 194
        radius: Ui.Theme.panelRadius
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.30)
        gradient: Gradient {
            GradientStop { position: 0; color: Ui.Theme.mix(Ui.Theme.surface, Ui.Theme.accent, 0.27) }
            GradientStop { position: 1; color: Ui.Theme.surfaceRaised }
        }

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingLg
            spacing: 2

            Row {
                width: parent.width
                height: 28
                Text {
                    width: parent.width - homeLabel.width
                    text: String(pane.city.label || "Location").toUpperCase()
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    id: homeLabel
                    visible: !!pane.city.home
                    text: "⌂  HOME"
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }

            Text {
                text: Visuals.localTime(pane.now.getTime(), pane.offsetSeconds)
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 64
                font.weight: Ui.Theme.fontWeightRegular
            }
            Text {
                text: Visuals.localDate(pane.now.getTime(), pane.offsetSeconds)
                color: Ui.Theme.mutedText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeBody
            }
            Text {
                text: (pane.city.abbreviation ? pane.city.abbreviation + "  ·  " : "")
                    + Visuals.utcOffset(pane.offsetSeconds)
                color: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }

        Row {
            id: heroTimeMetrics
            anchors.right: parent.right
            anchors.rightMargin: Ui.Theme.spacingLg
            anchors.top: parent.top
            anchors.topMargin: 56
            width: Math.min(300, parent.width * 0.46)
            height: 104

            Repeater {
                model: [
                    { daylight: true, label: "Day length", value: pane.hasSunTimes
                        ? Visuals.duration((pane.sunset - pane.sunrise) / 1000) : "—",
                        fraction: Visuals.daylightFraction(pane.sunrise, pane.sunset),
                        available: pane.hasSunTimes,
                        detail: pane.hasSunTimes ? "of 24 hours" : "Sun times unavailable" },
                    { daylight: false, label: "Moon", value: pane.moon.name,
                        fraction: pane.moon.fraction, available: true,
                        detail: pane.moon.illumination + "% illuminated" }
                ]
                delegate: Column {
                    id: heroTimeMetric
                    required property var modelData
                    width: heroTimeMetrics.width / 2
                    spacing: 2

                    TimeWeatherMetricIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(56, parent.width - Ui.Theme.spacingSm)
                        height: width
                        daylight: heroTimeMetric.modelData.daylight
                        fraction: heroTimeMetric.modelData.fraction
                        dataAvailable: heroTimeMetric.modelData.available
                        description: heroTimeMetric.modelData.label + ": "
                            + heroTimeMetric.modelData.value + ", "
                            + heroTimeMetric.modelData.detail
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: heroTimeMetric.modelData.label
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                    Text {
                        width: parent.width - Ui.Theme.spacingSm
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: heroTimeMetric.modelData.value
                        color: Ui.Theme.text
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Text {
                        visible: String(heroTimeMetric.modelData.detail || "").length > 0
                        width: parent.width - Ui.Theme.spacingSm
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: heroTimeMetric.modelData.detail || ""
                        color: Ui.Theme.subtleText
                        elide: Text.ElideRight
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: 9
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 250
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Ui.Theme.spacingMd
            text: "TODAY'S SUN POSITION IN " + String(pane.city.label || "LOCATION").toUpperCase()
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Canvas {
            id: sunCanvas
            x: Ui.Theme.spacingLg
            y: 43
            width: parent.width - Ui.Theme.spacingLg * 2
            height: 112
            onWidthChanged: requestPaint()
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                const margin = 20;
                const baseline = height - 20;
                const span = width - margin * 2;

                context.beginPath();
                context.moveTo(margin, baseline);
                context.quadraticCurveTo(width / 2, 1, width - margin, baseline);
                context.lineTo(width - margin, baseline);
                context.closePath();
                context.fillStyle = String(Ui.Theme.withAlpha(Ui.Theme.accent, 0.14));
                context.fill();

                context.beginPath();
                context.moveTo(0, baseline);
                context.lineTo(width, baseline);
                context.strokeStyle = String(Ui.Theme.border);
                context.lineWidth = 1;
                context.stroke();

                if (!pane.hasSunTimes)
                    return;
                const progress = pane.sunProgress;
                const x = margin + progress * span;
                const normalized = (x - margin) / span;
                const y = baseline - 4 * normalized * (1 - normalized) * (baseline - 5);
                context.beginPath();
                context.arc(x, y, 7, 0, Math.PI * 2);
                context.fillStyle = String(Ui.Theme.warning);
                context.fill();
                context.strokeStyle = String(Ui.Theme.withAlpha(Ui.Theme.text, 0.7));
                context.stroke();
            }
        }

        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Ui.Theme.spacingLg
            anchors.rightMargin: Ui.Theme.spacingLg
            anchors.bottomMargin: Ui.Theme.spacingMd
            height: 72

            Repeater {
                model: [
                    { label: "Rise", value: pane.time(pane.sunrise), icon: "󰖜" },
                    { label: "Solar noon", value: pane.time(pane.solarNoon), icon: "󰖙" },
                    { label: "Set", value: pane.time(pane.sunset), icon: "󰖛" }
                ]
                delegate: Column {
                    id: solarValue
                    required property var modelData
                    width: parent.width / 3
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: solarValue.modelData.icon
                        color: Ui.Theme.warning
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: Ui.Theme.iconSizeLarge
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: solarValue.modelData.label
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: solarValue.modelData.value
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeBody
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Math.round(116 + Math.max(0,
            width - Ui.Theme.spacingMd * 2) / 1.94)
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Ui.Theme.spacingMd
            text: "TIMEZONE"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.topMargin: 36
            text: pane.city.timezone || "Timezone unavailable"
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.topMargin: 37
            text: Visuals.utcOffset(pane.offsetSeconds)
            color: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeBody
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        TimezoneMap {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.topMargin: 74
            anchors.bottomMargin: Ui.Theme.spacingMd
            now: pane.now
            offsetSeconds: pane.offsetSeconds
            regionIds: pane.city.timezone_region_ids || []
            latitude: Number(pane.city.latitude || 0)
            longitude: Number(pane.city.longitude || 0)
            hasCoordinates: !!pane.city.has_coordinates
        }
    }
}
