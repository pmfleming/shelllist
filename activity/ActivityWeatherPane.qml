pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Ui.DetailFlickable {
    id: pane

    required property ActivityController controller
    required property date now

    readonly property var weather: controller.selectedWeather
    readonly property var locations: controller.weatherLocations
    readonly property var hourlyPoints: futureHours(weather.hourly || [])
    readonly property var forecastDays: (weather.daily || []).slice(0, 7)
    readonly property var heroColors: Visuals.heroColors(
        conditionCode(weather.condition_code), weather.is_day !== false)
    readonly property real hourlyMinimum: collectionMinimum(hourlyPoints, "temperature_c")
    readonly property real hourlyMaximum: collectionMaximum(hourlyPoints, "temperature_c")
    readonly property real weekMinimum: collectionMinimum(forecastDays, "low_c")
    readonly property real weekMaximum: collectionMaximum(forecastDays, "high_c")

    function numberLabel(value: var, suffix: string): string {
        const number = Number(value);
        return Number.isFinite(number) ? Math.round(number) + suffix : "—";
    }
    function conditionCode(value: var): int {
        const number = Number(value);
        return Number.isFinite(number) ? number : -1;
    }
    function futureHours(hours: var): var {
        const cutoff = Date.now() - 15 * 60 * 1000;
        const future = hours.filter(function (hour) {
            return Number(hour.time_unix_ms || 0) >= cutoff;
        });
        return (future.length > 0 ? future : hours).slice(0, 8);
    }
    function collectionMinimum(values: var, field: string): real {
        if (!values || values.length === 0)
            return 0;
        return Math.min.apply(null, values.map(function (value) {
            return Number(value[field] || 0);
        }));
    }
    function collectionMaximum(values: var, field: string): real {
        if (!values || values.length === 0)
            return 1;
        return Math.max.apply(null, values.map(function (value) {
            return Number(value[field] || 0);
        }));
    }
    function hourY(temperature: var): real {
        const range = Math.max(1, hourlyMaximum - hourlyMinimum);
        return 143 - (Number(temperature || 0) - hourlyMinimum) / range * 66;
    }
    function localTime(unixMs: var, weatherValue: var): string {
        return Visuals.localTime(unixMs,
            Number((weatherValue || weather).utc_offset_seconds || 0));
    }
    function localDay(unixMs: var): string {
        return Visuals.localDay(unixMs, Number(weather.utc_offset_seconds || 0));
    }
    function iconSource(name: string): url {
        return Qt.resolvedUrl("assets/weather/" + name + ".svg");
    }
    function revealSelectedLocation(): void {
        const index = locations.findIndex(function (location) {
            return location.id === weather.id;
        });
        if (index < 0)
            return;
        const card = locationRepeater.itemAt(index);
        if (!card)
            return;
        const target = card.x + card.width / 2 - locationFlick.width / 2;
        locationFlick.contentX = Math.max(0,
            Math.min(target, Math.max(0, locationFlick.contentWidth - locationFlick.width)));
    }

    onWeatherChanged: Qt.callLater(revealSelectedLocation)

    Rectangle {
        id: locationRail
        width: parent.width
        height: 108
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border
        clip: true

        Flickable {
            id: locationFlick
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingSm
            contentWidth: locationRow.width
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick
            interactive: contentWidth > width

            Behavior on contentX {
                enabled: !Ui.Theme.noAnimations
                NumberAnimation {
                    duration: Ui.Theme.animationInteractive
                    easing.type: Ui.Theme.easingResponsive
                }
            }

            Row {
                id: locationRow
                height: parent.height
                spacing: Ui.Theme.spacingSm

                Repeater {
                    id: locationRepeater
                    model: pane.locations

                    delegate: Rectangle {
                        id: locationCard

                        required property var modelData

                        width: Math.min(220, Math.max(174,
                            (locationRail.width - Ui.Theme.spacingSm * 4) / 3))
                        height: locationRow.height
                        radius: Ui.Theme.controlRadius
                        color: pane.weather.id === modelData.id
                            ? Ui.Theme.selected : Ui.Theme.surfaceRaised
                        border.width: pane.weather.id === modelData.id ? 2 : 1
                        border.color: pane.weather.id === modelData.id
                            ? Ui.Theme.accent : Ui.Theme.border

                        Text {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 10
                            anchors.topMargin: 7
                            width: parent.width - 68
                            text: locationCard.modelData.location || "—"
                            color: Ui.Theme.text
                            elide: Text.ElideRight
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeSmall
                            font.weight: Ui.Theme.fontWeightDemiBold
                        }

                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 9
                            anchors.topMargin: 7
                            text: (locationCard.modelData.home ? "⌂  " : "")
                                + pane.localTime(pane.now.getTime(), locationCard.modelData)
                            color: locationCard.modelData.home
                                ? Ui.Theme.accent : Ui.Theme.subtleText
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: Ui.Theme.fontSizeCaption
                        }

                        WeatherIcon {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 9
                            anchors.bottomMargin: 5
                            width: 53
                            height: 53
                            conditionCode: pane.conditionCode(locationCard.modelData.condition_code)
                            daytime: locationCard.modelData.is_day !== false
                            description: locationCard.modelData.condition || ""
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 68
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: 12
                            text: pane.numberLabel(locationCard.modelData.temperature_c, "°")
                            color: Ui.Theme.text
                            font.family: Ui.Theme.fontFamily
                            font.pixelSize: 29
                            font.weight: Ui.Theme.fontWeightRegular
                        }

                        Column {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 9
                            anchors.bottomMargin: 8
                            spacing: 1
                            Text {
                                anchors.right: parent.right
                                text: pane.numberLabel(locationCard.modelData.high_c, "°")
                                    + "  " + pane.numberLabel(locationCard.modelData.low_c, "°")
                                color: Ui.Theme.mutedText
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                            Row {
                                anchors.right: parent.right
                                spacing: 2
                                Image {
                                    width: 13
                                    height: 13
                                    source: pane.iconSource("raindrop")
                                    fillMode: Image.PreserveAspectFit
                                }
                                Text {
                                    text: pane.numberLabel(
                                        locationCard.modelData.precipitation_probability, "%")
                                    color: Ui.Theme.accent
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeCaption
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pane.controller.selectWeatherLocation(
                                locationCard.modelData.id)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 192
        radius: Ui.Theme.panelRadius
        border.color: Qt.rgba(1, 1, 1, 0.12)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: pane.heroColors[0] }
            GradientStop { position: 1; color: pane.heroColors[1] }
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingLg
            anchors.topMargin: Ui.Theme.spacingMd
            text: String(pane.weather.location || "—").toUpperCase()
            color: "#f4f7fb"
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeLabel
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingLg
            anchors.topMargin: 39
            text: pane.localTime(pane.now.getTime(), pane.weather)
            color: "#d6dfec"
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeHeading
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Ui.Theme.spacingMd
            anchors.topMargin: Ui.Theme.spacingSm
            text: Number(pane.weather.updated_unix_ms || 0) > 0
                ? "↻ " + pane.localTime(pane.weather.updated_unix_ms, pane.weather) : ""
            color: "#aebdd0"
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        WeatherIcon {
            anchors.left: parent.left
            anchors.leftMargin: Math.max(130, parent.width * 0.25)
            anchors.verticalCenter: parent.verticalCenter
            width: 145
            height: 145
            conditionCode: pane.conditionCode(pane.weather.condition_code)
            daytime: pane.weather.is_day !== false
            description: pane.weather.condition || ""
        }

        Column {
            anchors.right: parent.right
            anchors.rightMargin: Ui.Theme.spacingLg
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                anchors.right: parent.right
                text: pane.numberLabel(pane.weather.temperature_c, "°")
                color: "#ffffff"
                font.family: Ui.Theme.fontFamily
                font.pixelSize: 66
                font.weight: Ui.Theme.fontWeightRegular
            }
            Text {
                anchors.right: parent.right
                text: pane.numberLabel(pane.weather.high_c, "°") + "  "
                    + pane.numberLabel(pane.weather.low_c, "°")
                color: "#d6dfec"
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
                    { icon: "thermometer", value: pane.numberLabel(
                        pane.weather.apparent_temperature_c, "°") },
                    { icon: "raindrop", value: pane.numberLabel(
                        pane.weather.precipitation_probability, "%") },
                    { icon: "wind", value: Visuals.windCompass(
                        pane.weather.wind_direction_degrees) + "  "
                        + pane.numberLabel(pane.weather.wind_speed_kmh, " km/h") }
                ]
                delegate: Row {
                    id: heroMetric
                    required property var modelData
                    spacing: 4
                    Image {
                        width: 21
                        height: 21
                        source: pane.iconSource(heroMetric.modelData.icon)
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: heroMetric.modelData.value
                        color: "#e2e9f2"
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }

    Rectangle {
        id: hourlyCard
        width: parent.width
        height: 232
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.topMargin: 8
            text: "12H"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Canvas {
            id: hourlyChart
            anchors.fill: parent
            anchors.margins: 10

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: pane
                function onHourlyPointsChanged() { hourlyChart.requestPaint(); }
                function onHourlyMinimumChanged() { hourlyChart.requestPaint(); }
                function onHourlyMaximumChanged() { hourlyChart.requestPaint(); }
            }
            onPaint: {
                const context = getContext("2d");
                context.clearRect(0, 0, width, height);
                const points = pane.hourlyPoints;
                if (points.length < 2)
                    return;
                const slot = width / points.length;

                context.fillStyle = "rgba(47, 140, 255, 0.22)";
                for (let index = 0; index < points.length; ++index) {
                    const probability = Number(points[index].precipitation_probability || 0);
                    const barHeight = probability / 100 * 28;
                    context.fillRect(index * slot + slot * 0.31, 183 - barHeight,
                        slot * 0.38, barHeight);
                }

                context.beginPath();
                for (let index = 0; index < points.length; ++index) {
                    const x = index * slot + slot / 2;
                    const y = pane.hourY(points[index].temperature_c);
                    if (index === 0)
                        context.moveTo(x, y);
                    else
                        context.lineTo(x, y);
                }
                context.strokeStyle = String(Ui.Theme.accent);
                context.lineWidth = 2.5;
                context.stroke();

                context.fillStyle = String(Ui.Theme.accent);
                for (let index = 0; index < points.length; ++index) {
                    const x = index * slot + slot / 2;
                    const y = pane.hourY(points[index].temperature_c);
                    context.beginPath();
                    context.arc(x, y, 3.5, 0, Math.PI * 2);
                    context.fill();
                }
            }
        }

        Repeater {
            model: pane.hourlyPoints
            delegate: Item {
                id: hourPoint
                required property var modelData
                required property int index
                width: hourlyCard.width / Math.max(1, pane.hourlyPoints.length)
                height: hourlyCard.height
                x: index * width

                WeatherIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 18
                    width: 38
                    height: 38
                    conditionCode: pane.conditionCode(hourPoint.modelData.condition_code)
                    daytime: hourPoint.modelData.is_day !== false
                    description: hourPoint.modelData.condition || ""
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: pane.hourY(hourPoint.modelData.temperature_c) - 20
                    text: pane.numberLabel(hourPoint.modelData.temperature_c, "°")
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 184
                    text: Number(hourPoint.modelData.precipitation_probability || 0) > 0
                        ? pane.numberLabel(hourPoint.modelData.precipitation_probability, "%") : ""
                    color: Ui.Theme.accent
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: 9
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 7
                    text: pane.localTime(hourPoint.modelData.time_unix_ms, pane.weather)
                    color: Ui.Theme.subtleText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }
        }

        Text {
            visible: pane.hourlyPoints.length < 2
            anchors.centerIn: parent
            text: "—"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeDisplay
        }
    }

    Rectangle {
        width: parent.width
        height: 43 + pane.forecastDays.length * 43
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.leftMargin: Ui.Theme.spacingMd
            anchors.topMargin: 10
            text: "7D"
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
            font.weight: Ui.Theme.fontWeightDemiBold
        }

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 36

            Repeater {
                model: pane.forecastDays
                delegate: Item {
                    id: dayRow
                    required property var modelData
                    width: parent.width
                    height: 43

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Ui.Theme.border
                        opacity: 0.6
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: Ui.Theme.spacingMd
                        anchors.verticalCenter: parent.verticalCenter
                        width: 43
                        text: pane.localDay(dayRow.modelData.date_unix_ms)
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                    WeatherIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 59
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        conditionCode: pane.conditionCode(dayRow.modelData.condition_code)
                        daytime: true
                        description: dayRow.modelData.condition || ""
                    }
                    Image {
                        anchors.left: parent.left
                        anchors.leftMargin: 105
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        height: 16
                        source: pane.iconSource("raindrop")
                        fillMode: Image.PreserveAspectFit
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 123
                        anchors.verticalCenter: parent.verticalCenter
                        width: 39
                        text: pane.numberLabel(dayRow.modelData.precipitation_probability, "%")
                        color: Ui.Theme.accent
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeCaption
                    }
                    Text {
                        anchors.right: temperatureRange.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: pane.numberLabel(dayRow.modelData.low_c, "°")
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                    Item {
                        id: temperatureRange
                        anchors.right: parent.right
                        anchors.rightMargin: 55
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(170, parent.width * 0.37)
                        height: 8

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Ui.Theme.surfaceRaised
                            border.color: Ui.Theme.border
                        }
                        Rectangle {
                            readonly property real span: Math.max(1,
                                pane.weekMaximum - pane.weekMinimum)
                            x: (Number(dayRow.modelData.low_c || 0) - pane.weekMinimum)
                                / span * parent.width
                            width: Math.max(8,
                                (Number(dayRow.modelData.high_c || 0)
                                    - Number(dayRow.modelData.low_c || 0))
                                / span * parent.width)
                            height: parent.height
                            radius: height / 2
                            color: Ui.Theme.accent
                        }
                    }
                    Text {
                        anchors.left: temperatureRange.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: pane.numberLabel(dayRow.modelData.high_c, "°")
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }

    Row {
        id: visualMetrics
        width: parent.width
        height: 106
        spacing: Ui.Theme.spacingSm

        Repeater {
            model: [
                { icon: "humidity", value: pane.numberLabel(
                    pane.weather.humidity_percent, "%") },
                { icon: "wind", value: Visuals.windCompass(
                    pane.weather.wind_direction_degrees) + "  "
                    + pane.numberLabel(pane.weather.wind_gust_kmh, " km/h") },
                { icon: "sunrise", value: pane.localTime(
                    pane.weather.sunrise_unix_ms, pane.weather) },
                { icon: "sunset", value: pane.localTime(
                    pane.weather.sunset_unix_ms, pane.weather) }
            ]
            delegate: Rectangle {
                id: visualMetric
                required property var modelData
                width: (visualMetrics.width - visualMetrics.spacing * 3) / 4
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border

                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: 48
                    height: 48
                    source: pane.iconSource(visualMetric.modelData.icon)
                    fillMode: Image.PreserveAspectFit
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    text: visualMetric.modelData.value
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeBody
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }
}
