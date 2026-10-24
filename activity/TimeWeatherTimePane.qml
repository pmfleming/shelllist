pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: pane

    required property var city

    readonly property var weather: city.weather || ({})
    readonly property bool clockAvailable: WeatherVisuals.hasLocationClock(city)
    readonly property var display: weather.display || ({})
    readonly property int offsetSeconds: clockAvailable ? city.utc_offset_seconds : 0
    readonly property bool hasSunTimes: display.sun_available === true
    readonly property real sunProgress: display.sun_progress || 0
    readonly property var moon: city.lunar || null

    readonly property var moonNames: ({
            "new-moon": qsTr("New moon"),
            "waxing-crescent": qsTr("Waxing crescent"),
            "first-quarter": qsTr("First quarter"),
            "waxing-gibbous": qsTr("Waxing gibbous"),
            "full-moon": qsTr("Full moon"),
            "waning-gibbous": qsTr("Waning gibbous"),
            "last-quarter": qsTr("Last quarter"),
            "waning-crescent": qsTr("Waning crescent")
        })

    function moonName(phase: string): string {
        return Object.prototype.hasOwnProperty.call(moonNames, phase) ? moonNames[phase] : qsTr("Unavailable");
    }

    onSunProgressChanged: sunCanvas.requestPaint()
    onWidthChanged: sunCanvas.requestPaint()

    Rectangle {
        id: timeHero
        objectName: "timeHero"
        readonly property bool stacked: width < 600
        width: parent.width
        height: Math.max(194, clockText.implicitHeight + 2 * Ui.Theme.spacingLg, heroTimeMetrics.y + heroTimeMetrics.implicitHeight + Ui.Theme.spacingLg)
        radius: Ui.Theme.panelRadius
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.30)
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Ui.Theme.mix(Ui.Theme.surface, Ui.Theme.accent, 0.27)
            }
            GradientStop {
                position: 1
                color: Ui.Theme.surfaceRaised
            }
        }

        Column {
            id: clockText
            x: Ui.Theme.spacingLg
            y: Ui.Theme.spacingLg
            width: parent.width - 2 * Ui.Theme.spacingLg - (timeHero.stacked ? 0 : heroTimeMetrics.width + Ui.Theme.spacingMd)
            spacing: 2

            Row {
                width: parent.width
                height: 28
                Ui.ThemeText {
                    width: parent.width - homeLabel.width
                    text: String(pane.city.label || qsTr("Location"))
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Ui.GlyphLabel {
                    id: homeLabel
                    visible: !!pane.city.home
                    glyph: "󰋜"
                    color: Ui.Theme.accent
                    font.pixelSize: Ui.Theme.iconSizeSmall
                    Accessible.name: qsTr("Home location")
                    Accessible.role: Accessible.StaticText
                }
            }

            Ui.ThemeText {
                objectName: "locationClockTime"
                text: pane.clockAvailable ? pane.city.clock_display.time : "—"
                font.pixelSize: Ui.Theme.heroClockSize
            }
            Ui.ThemeText {
                objectName: "locationClockDate"
                text: pane.clockAvailable ? (pane.city.clock_display.date || "—") : "—"
                color: Ui.Theme.mutedText
            }
            Ui.ThemeText {
                objectName: "locationClockZone"
                text: pane.clockAvailable ? (pane.city.abbreviation ? pane.city.abbreviation + "  ·  " : "") + (pane.city.clock_display.offset || "") : qsTr("Timezone unavailable")
                color: Ui.Theme.accent
                font.pixelSize: Ui.Theme.fontSizeSmall
                font.weight: Ui.Theme.fontWeightDemiBold
            }
        }

        Row {
            id: heroTimeMetrics
            objectName: "timeHeroMetrics"
            x: timeHero.stacked ? Ui.Theme.spacingLg : parent.width - width - Ui.Theme.spacingLg
            y: timeHero.stacked ? clockText.y + clockText.implicitHeight + Ui.Theme.spacingMd : 56
            width: timeHero.stacked ? parent.width - 2 * Ui.Theme.spacingLg : Math.min(300, parent.width * 0.46)
            height: implicitHeight

            Repeater {
                model: [
                    {
                        daylight: true,
                        label: "Day length",
                        value: pane.display.daylight || "—",
                        fraction: pane.display.daylight_fraction || 0,
                        available: pane.hasSunTimes,
                        detail: pane.hasSunTimes ? "of 24 hours" : "Sun times unavailable"
                    },
                    {
                        daylight: false,
                        label: "Moon",
                        value: pane.moonName((pane.moon || ({})).phase || ""),
                        fraction: pane.moon ? pane.moon.fraction : 0,
                        available: !!pane.moon,
                        detail: pane.moon ? qsTr("Approx. %1% illuminated").arg(pane.moon.illumination_percent) : qsTr("Lunar estimate unavailable")
                    }
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
                        description: heroTimeMetric.modelData.label + ": " + heroTimeMetric.modelData.value + ", " + heroTimeMetric.modelData.detail
                    }
                    Ui.ThemeText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: heroTimeMetric.modelData.label
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.metadataSize
                    }
                    Ui.ThemeText {
                        width: parent.width - Ui.Theme.spacingSm
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: heroTimeMetric.modelData.value
                        elide: Text.ElideRight
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    Ui.ThemeText {
                        objectName: "timeMetricDetail-" + (heroTimeMetric.modelData.daylight ? "daylight" : "moon")
                        visible: String(heroTimeMetric.modelData.detail || "").length > 0
                        width: parent.width - Ui.Theme.spacingSm
                        anchors.horizontalCenter: parent.horizontalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: heroTimeMetric.modelData.detail || ""
                        color: Ui.Theme.subtleText
                        wrapMode: Text.Wrap
                        font.pixelSize: Ui.Theme.metadataSize
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 250
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surface
        border.width: 0

        Ui.ThemeText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Ui.Theme.spacingMd
            text: qsTr("Sun position")
            font.pixelSize: Ui.Theme.groupHeadingSize
            font.weight: Ui.Theme.groupHeadingWeight
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
                    {
                        label: "Rise",
                        value: pane.display.sunrise || "—",
                        icon: "󰖜"
                    },
                    {
                        label: qsTr("Approx. solar noon"),
                        value: pane.display.solar_noon || "—",
                        icon: "󰖙"
                    },
                    {
                        label: "Set",
                        value: pane.display.sunset || "—",
                        icon: "󰖛"
                    }
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
                    Ui.ThemeText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: solarValue.modelData.label
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.metadataSize
                    }
                    Ui.ThemeText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: solarValue.modelData.value
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Math.round(116 + Math.max(0, width - Ui.Theme.spacingMd * 2) / 1.94)
        radius: Ui.Theme.cardRadius
        color: Ui.Theme.surface
        border.width: 0

        Ui.ThemeText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Ui.Theme.spacingMd
            text: qsTr("Timezone")
            font.pixelSize: Ui.Theme.groupHeadingSize
            font.weight: Ui.Theme.groupHeadingWeight
        }
        Ui.ThemeText {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.topMargin: 36
            text: pane.city.timezone || "Timezone unavailable"
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightDemiBold
        }
        Ui.ThemeText {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.topMargin: 37
            text: pane.clockAvailable ? (pane.city.clock_display.offset || "") : qsTr("Timezone unavailable")
            color: Ui.Theme.accent
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        TimezoneMap {
            objectName: "locationTimezoneMap"
            clockAvailable: pane.clockAvailable
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.topMargin: 74
            anchors.bottomMargin: Ui.Theme.spacingMd
            clockLabel: pane.city.clock_display?.time || "—"
            offsetLabel: pane.city.clock_display?.offset || ""
            offsetSeconds: pane.offsetSeconds
            regionIds: pane.city.timezone_region_ids || []
            latitude: Number(pane.city.latitude || 0)
            longitude: Number(pane.city.longitude || 0)
            hasCoordinates: !!pane.city.has_coordinates
        }
    }
}
