pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property date now

    readonly property var weather: controller.selectedWeather
    readonly property var locations: controller.weatherLocations
    readonly property var otherLocations: locations.filter(function (location) {
        return !location.home;
    })
    readonly property var futureDays: (weather.daily || []).slice(1, 8)
    property string chartMode: "temperature"
    readonly property color chartColor: chartMode === "temperature" ? Ui.Theme.warning
        : chartMode === "precipitation" ? Ui.Theme.accent : "#a78bfa"

    function numberLabel(value: var, suffix: string): string {
        const number = Number(value);
        return Number.isFinite(number) ? Math.round(number) + suffix : "—";
    }
    function localTime(weatherValue: var): string {
        const shifted = new Date(now.getTime()
            + Number(weatherValue.utc_offset_seconds || 0) * 1000);
        return String(shifted.getUTCHours()).padStart(2, "0") + ":"
            + String(shifted.getUTCMinutes()).padStart(2, "0");
    }
    function conditionIcon(condition: string): string {
        const value = String(condition || "").toLowerCase();
        if (value.indexOf("thunder") >= 0)
            return "󰖓";
        if (value.indexOf("snow") >= 0)
            return "󰖘";
        if (value.indexOf("rain") >= 0 || value.indexOf("drizzle") >= 0)
            return "󰖗";
        if (value.indexOf("fog") >= 0)
            return "󰖑";
        if (value.indexOf("cloud") >= 0 || value.indexOf("overcast") >= 0)
            return "󰖐";
        return "󰖙";
    }
    function chartValue(hour: var): real {
        if (chartMode === "precipitation")
            return Number(hour.precipitation_probability || 0);
        if (chartMode === "wind")
            return Number(hour.wind_speed_kmh || 0);
        return Number(hour.temperature_c || 0);
    }
    function chartSuffix(): string {
        return chartMode === "temperature" ? "°"
            : chartMode === "precipitation" ? "%" : " km/h";
    }
    function locationOptions(): var {
        return locations.map(function (location) {
            return { value: location.id, label: (location.home ? "Home · " : "")
                + location.location };
        });
    }
    function metricTime(unixMs: var): string {
        const value = Number(unixMs || 0);
        return value > 0 ? Qt.formatTime(new Date(value), "HH:mm") : "—";
    }

    spacing: Ui.Theme.spacingMd

    Rectangle {
        width: parent.width
        height: Math.min(460, Math.max(420, pane.height * 0.48))
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingLg
            spacing: Ui.Theme.spacingSm

            Row {
                width: parent.width
                height: 40
                spacing: Ui.Theme.spacingSm
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍎"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Ui.Theme.iconSize
                }
                Ui.DropDownList {
                    width: Math.min(260, parent.width * 0.42)
                    height: parent.height
                    options: pane.locationOptions()
                    value: String(pane.weather.id || "")
                    placeholder: "Choose location"
                    onSelected: function (locationId) {
                        pane.controller.selectWeatherLocation(locationId);
                    }
                }
                Item { width: parent.width - x - updatedText.width; height: 1 }
                Text {
                    id: updatedText
                    anchors.verticalCenter: parent.verticalCenter
                    text: pane.weather.available && Number(pane.weather.updated_unix_ms || 0) > 0
                        ? "Updated " + Qt.formatTime(new Date(Number(pane.weather.updated_unix_ms)), "HH:mm")
                        : "Forecast unavailable"
                    color: Ui.Theme.subtleText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }
            }


            Row {
                width: parent.width
                height: 34
                spacing: Ui.Theme.spacingXs
                Repeater {
                    model: [
                        { id: "temperature", label: "Temperature" },
                        { id: "precipitation", label: "Precipitation" },
                        { id: "wind", label: "Wind" }
                    ]
                    delegate: ActivityHeaderButton {
                        required property var modelData
                        label: modelData.label
                        checked: pane.chartMode === modelData.id
                        onTriggered: pane.chartMode = modelData.id
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 142
                radius: Ui.Theme.controlRadius
                color: Ui.Theme.surfaceRaised
                border.color: Ui.Theme.border

                Canvas {
                    id: forecastChart
                    anchors.fill: parent
                    anchors.margins: 10
                    readonly property var points: (pane.weather.hourly || []).slice(1, 9)

                    onPointsChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Connections {
                        target: pane
                        function onChartModeChanged() { forecastChart.requestPaint(); }
                        function onChartColorChanged() { forecastChart.requestPaint(); }
                    }
                    onPaint: {
                        const context = getContext("2d");
                        context.clearRect(0, 0, width, height);
                        if (points.length < 2)
                            return;
                        const values = points.map(function (point) { return pane.chartValue(point); });
                        let minimum = Math.min.apply(null, values);
                        let maximum = Math.max.apply(null, values);
                        if (maximum - minimum < 1) {
                            minimum -= 0.5;
                            maximum += 0.5;
                        }
                        const top = 20;
                        const bottom = height - 25;
                        const step = width / (points.length - 1);
                        function pointY(value) {
                            return bottom - (value - minimum) / (maximum - minimum) * (bottom - top);
                        }
                        context.beginPath();
                        context.moveTo(0, bottom);
                        for (let index = 0; index < values.length; ++index)
                            context.lineTo(index * step, pointY(values[index]));
                        context.lineTo(width, bottom);
                        context.closePath();
                        context.fillStyle = pane.chartMode === "temperature"
                            ? "rgba(245, 158, 11, 0.22)"
                            : pane.chartMode === "precipitation"
                                ? "rgba(47, 140, 255, 0.22)" : "rgba(167, 139, 250, 0.22)";
                        context.fill();
                        context.beginPath();
                        for (let index = 0; index < values.length; ++index) {
                            const x = index * step;
                            const y = pointY(values[index]);
                            if (index === 0)
                                context.moveTo(x, y);
                            else
                                context.lineTo(x, y);
                        }
                        context.strokeStyle = String(pane.chartColor);
                        context.lineWidth = 2;
                        context.stroke();
                        context.fillStyle = String(Ui.Theme.mutedText);
                        context.font = "10px " + Ui.Theme.fontFamily;
                        context.textAlign = "center";
                        for (let index = 0; index < values.length; ++index) {
                            const x = index * step;
                            const y = pointY(values[index]);
                            context.fillText(Math.round(values[index]) + pane.chartSuffix(), x, y - 7);
                            context.fillText(Qt.formatTime(new Date(Number(points[index].time_unix_ms)),
                                "HH:mm"), x, height - 6);
                        }
                    }
                }

                Text {
                    visible: (pane.weather.hourly || []).length < 2
                    anchors.centerIn: parent
                    text: "Hourly forecast appears when weather is configured"
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeSmall
                }
            }

            Row {
                id: dailyRow
                width: parent.width
                height: parent.height - y
                spacing: Ui.Theme.spacingSm
                Repeater {
                    model: pane.futureDays
                    delegate: Rectangle {
                        id: dayCard
                        required property var modelData
                        width: (dailyRow.width - dailyRow.spacing
                            * Math.max(0, pane.futureDays.length - 1))
                            / Math.max(1, pane.futureDays.length)
                        height: parent.height
                        radius: Ui.Theme.controlRadius
                        color: Ui.Theme.surfaceRaised
                        border.color: Ui.Theme.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 7
                            spacing: 4
                            Text {
                                width: parent.width
                                text: Qt.formatDate(new Date(Number(dayCard.modelData.date_unix_ms)), "ddd")
                                color: Ui.Theme.text
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeBody
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                            Text {
                                width: parent.width
                                text: pane.conditionIcon(dayCard.modelData.condition)
                                color: Ui.Theme.text
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.iconFontFamily
                                font.pixelSize: Ui.Theme.iconSizeLarge
                            }
                            Text {
                                width: parent.width
                                text: pane.numberLabel(dayCard.modelData.high_c, "°") + "  "
                                    + pane.numberLabel(dayCard.modelData.low_c, "°")
                                color: Ui.Theme.mutedText
                                horizontalAlignment: Text.AlignHCenter
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        width: parent.width
        height: 130
        radius: Ui.Theme.panelRadius
        color: Ui.Theme.surface
        border.color: Ui.Theme.border

        Column {
            anchors.fill: parent
            anchors.margins: Ui.Theme.spacingMd
            spacing: Ui.Theme.spacingSm
            Text {
                text: "Other locations · weather and local time"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeLabel
                font.weight: Ui.Theme.fontWeightDemiBold
            }
            Row {
                id: locationRow
                width: parent.width
                height: parent.height - y
                spacing: Ui.Theme.spacingSm
                Repeater {
                    model: pane.otherLocations
                    delegate: Rectangle {
                        id: locationCard
                        required property var modelData
                        width: (locationRow.width - locationRow.spacing
                            * Math.max(0, pane.otherLocations.length - 1))
                            / Math.max(1, pane.otherLocations.length)
                        height: parent.height
                        radius: Ui.Theme.controlRadius
                        color: pane.weather.id === modelData.id
                            ? Ui.Theme.selected : Ui.Theme.surfaceRaised
                        border.color: pane.weather.id === modelData.id
                            ? Ui.Theme.accent : Ui.Theme.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            Text {
                                width: parent.width
                                text: (locationCard.modelData.home ? "Home · " : "")
                                    + locationCard.modelData.location
                                color: Ui.Theme.text
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeSmall
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                            Text {
                                width: parent.width
                                text: pane.localTime(locationCard.modelData)
                                color: Ui.Theme.accent
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeHeading
                            }
                            Text {
                                width: parent.width
                                text: pane.numberLabel(locationCard.modelData.temperature_c, "°")
                                    + " · " + (locationCard.modelData.condition || "Unavailable")
                                color: Ui.Theme.mutedText
                                elide: Text.ElideRight
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pane.controller.selectWeatherLocation(locationCard.modelData.id)
                        }
                    }
                }
            }
        }
    }

    Row {
        id: metricsRow
        width: parent.width
        height: Math.max(100, parent.height - y)
        spacing: Ui.Theme.spacingMd
        Repeater {
            model: [
                { label: "Precipitation", value: pane.numberLabel(pane.weather.precipitation_probability, "%") },
                { label: "Humidity", value: pane.numberLabel(pane.weather.humidity_percent, "%") },
                { label: "Wind", value: pane.numberLabel(pane.weather.wind_speed_kmh, " km/h") },
                { label: "Daylight", value: pane.metricTime(pane.weather.sunrise_unix_ms)
                    + "–" + pane.metricTime(pane.weather.sunset_unix_ms) }
            ]
            delegate: Rectangle {
                id: metricCard
                required property var modelData
                width: (metricsRow.width - metricsRow.spacing * 3) / 4
                height: parent.height
                radius: Ui.Theme.panelRadius
                color: Ui.Theme.surface
                border.color: Ui.Theme.border
                Column {
                    anchors.fill: parent
                    anchors.margins: Ui.Theme.spacingMd
                    spacing: Ui.Theme.spacingSm
                    Text {
                        text: metricCard.modelData.label
                        color: Ui.Theme.mutedText
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                    Text {
                        text: metricCard.modelData.value
                        color: Ui.Theme.text
                        font.family: Ui.Theme.fontFamily
                        font.pixelSize: Ui.Theme.fontSizeDisplay
                        font.weight: Ui.Theme.fontWeightDemiBold
                    }
                }
            }
        }
    }
}
