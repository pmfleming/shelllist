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
    }

    Rectangle {
        id: solarCard
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

    Row {
        id: timeMetrics
        width: parent.width
        height: 126
        spacing: Ui.Theme.spacingMd

        Repeater {
            model: [
                { icon: "󰖙", label: "Day length", value: pane.hasSunTimes
                    ? Visuals.duration((pane.sunset - pane.sunrise) / 1000) : "—" },
                { icon: "󰽤", label: "Moon", value: pane.moon.name
                    + "  ·  " + pane.moon.illumination + "%" }
            ]
            delegate: Rectangle {
                id: timeMetric
                required property var modelData
                width: (timeMetrics.width - timeMetrics.spacing) / 2
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 14
                    text: timeMetric.modelData.icon
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: 34
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 55
                    text: timeMetric.modelData.label
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 15
                    text: timeMetric.modelData.value
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeBody
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }

    Rectangle {
        id: timezoneCard
        width: parent.width
        height: 188
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

        Item {
            id: offsetRail
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.bottomMargin: Ui.Theme.spacingMd
            height: 74
            readonly property real offsetHours: pane.offsetSeconds / 3600
            readonly property real markerX: Math.max(0, Math.min(width,
                (offsetHours + 12) / 26 * width))

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 30
                spacing: 1
                Repeater {
                    model: 26
                    Rectangle {
                        required property int index
                        width: (offsetRail.width - 25) / 26
                        height: parent.height
                        color: index % 2 === 0
                            ? Ui.Theme.withAlpha(Ui.Theme.accent, 0.24)
                            : Ui.Theme.withAlpha(Ui.Theme.warning, 0.20)
                    }
                }
            }
            Rectangle {
                x: offsetRail.markerX - 1
                y: -5
                width: 3
                height: 45
                radius: 2
                color: Ui.Theme.accent
            }
            Text {
                x: Math.max(0, Math.min(parent.width - width,
                    offsetRail.markerX - width / 2))
                y: 40
                text: pane.city.abbreviation || Visuals.utcOffset(pane.offsetSeconds)
                color: Ui.Theme.accent
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeCaption
                font.weight: Ui.Theme.fontWeightBold
            }
            Text {
                anchors.left: parent.left
                y: 40
                text: "−12"
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 9
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                text: "UTC"
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 9
            }
            Text {
                anchors.right: parent.right
                y: 40
                text: "+14"
                color: Ui.Theme.subtleText
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 9
            }
        }
    }
}
