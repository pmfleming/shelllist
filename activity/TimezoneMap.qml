import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: map

    required property date now
    property int offsetSeconds: 0
    property string timezoneName: ""
    property string abbreviation: ""

    radius: Ui.Theme.controlRadius
    color: Ui.Theme.surfaceRaised
    border.color: Ui.Theme.border
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "World timezone map. " + (timezoneName || "Selected timezone")
        + ", " + Visuals.utcOffset(offsetSeconds) + ", local time "
        + Visuals.localTime(now.getTime(), offsetSeconds)

    function drawPolygon(context: var, points: var, left: real, top: real,
            mapWidth: real, mapHeight: real): void {
        context.beginPath();
        points.forEach(function (point, index) {
            const x = left + point[0] * mapWidth;
            const y = top + point[1] * mapHeight;
            if (index === 0)
                context.moveTo(x, y);
            else
                context.lineTo(x, y);
        });
        context.closePath();
        context.fill();
        context.stroke();
    }

    onNowChanged: timezoneCanvas.requestPaint()
    onOffsetSecondsChanged: timezoneCanvas.requestPaint()
    onAbbreviationChanged: timezoneCanvas.requestPaint()

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Ui.Theme.spacingSm
        anchors.topMargin: Ui.Theme.spacingSm
        text: "WORLD TIME ZONES"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Ui.Theme.spacingSm
        anchors.topMargin: Ui.Theme.spacingSm
        text: Visuals.localTime(map.now.getTime(), map.offsetSeconds)
        color: Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Canvas {
        id: timezoneCanvas

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 1
        anchors.rightMargin: 1
        anchors.topMargin: 30
        anchors.bottomMargin: 1

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        onPaint: {
            const context = getContext("2d");
            context.clearRect(0, 0, width, height);

            const bandWidth = width / 26;
            const mapTop = 25;
            const mapBottom = height - 22;
            const mapHeight = mapBottom - mapTop;
            const selectedX = Visuals.timezonePosition(map.offsetSeconds) * width;

            for (let index = 0; index < 26; index += 1) {
                const offset = index - 12;
                const localHour = new Date(map.now.getTime()
                    + offset * 3600000).getUTCHours();
                const nighttime = localHour < 6 || localHour >= 18;
                context.fillStyle = String(nighttime
                    ? Ui.Theme.withAlpha(Ui.Theme.window, 0.44)
                    : Ui.Theme.withAlpha(Ui.Theme.accent, index % 2 === 0 ? 0.11 : 0.07));
                context.fillRect(index * bandWidth, 0, bandWidth + 1, mapBottom);
            }

            context.fillStyle = String(Ui.Theme.withAlpha(Ui.Theme.accent, 0.24));
            context.fillRect(Math.max(0, selectedX - bandWidth / 2), 0,
                Math.min(bandWidth, width - Math.max(0, selectedX - bandWidth / 2)), mapBottom);

            context.lineWidth = 1;
            for (let index = 0; index <= 26; index += 2) {
                const x = index * bandWidth;
                context.beginPath();
                context.moveTo(x, 0);
                context.lineTo(x, mapBottom);
                context.strokeStyle = String(Ui.Theme.withAlpha(Ui.Theme.border, 0.46));
                context.stroke();
            }

            context.beginPath();
            context.moveTo(0, mapTop + mapHeight / 2);
            context.lineTo(width, mapTop + mapHeight / 2);
            context.strokeStyle = String(Ui.Theme.withAlpha(Ui.Theme.border, 0.34));
            context.stroke();

            context.fillStyle = String(Ui.Theme.withAlpha(Ui.Theme.text, 0.16));
            context.strokeStyle = String(Ui.Theme.withAlpha(Ui.Theme.text, 0.34));
            context.lineWidth = 1;
            const continents = [
                [[0.02, 0.27], [0.07, 0.13], [0.16, 0.08], [0.24, 0.14],
                    [0.29, 0.24], [0.27, 0.32], [0.23, 0.35], [0.20, 0.47],
                    [0.15, 0.51], [0.12, 0.43], [0.08, 0.39], [0.04, 0.38]],
                [[0.25, 0.05], [0.31, 0.03], [0.34, 0.13], [0.30, 0.22],
                    [0.26, 0.18]],
                [[0.22, 0.48], [0.29, 0.46], [0.34, 0.55], [0.33, 0.66],
                    [0.29, 0.84], [0.25, 0.74], [0.22, 0.57]],
                [[0.40, 0.27], [0.47, 0.18], [0.57, 0.18], [0.64, 0.12],
                    [0.75, 0.15], [0.84, 0.20], [0.94, 0.28], [0.89, 0.37],
                    [0.80, 0.39], [0.72, 0.34], [0.67, 0.40], [0.59, 0.37],
                    [0.54, 0.43], [0.47, 0.38], [0.42, 0.40]],
                [[0.45, 0.39], [0.54, 0.38], [0.60, 0.48], [0.57, 0.64],
                    [0.52, 0.77], [0.47, 0.65], [0.44, 0.50]],
                [[0.60, 0.39], [0.67, 0.42], [0.70, 0.55], [0.66, 0.62],
                    [0.62, 0.50]],
                [[0.76, 0.63], [0.85, 0.59], [0.92, 0.68], [0.89, 0.78],
                    [0.81, 0.81], [0.75, 0.73]],
                [[0.96, 0.58], [0.98, 0.66], [0.97, 0.72], [0.95, 0.66]]
            ];
            continents.forEach(function (points) {
                map.drawPolygon(context, points, 0, mapTop, width, mapHeight);
            });

            context.beginPath();
            context.moveTo(selectedX, 0);
            context.lineTo(selectedX, mapBottom);
            context.strokeStyle = String(Ui.Theme.accent);
            context.lineWidth = 2;
            context.stroke();

            const selectedLabel = map.abbreviation || Visuals.utcOffset(map.offsetSeconds);
            context.font = "600 10px " + Ui.Theme.fontFamily;
            const labelWidth = context.measureText(selectedLabel).width + 12;
            const labelX = Math.max(3, Math.min(width - labelWidth - 3,
                selectedX - labelWidth / 2));
            context.fillStyle = String(Ui.Theme.accent);
            context.fillRect(labelX, 3, labelWidth, 18);
            context.fillStyle = String(Ui.Theme.accentText);
            context.textAlign = "center";
            context.textBaseline = "middle";
            context.fillText(selectedLabel, labelX + labelWidth / 2, 12);

            context.font = "9px " + Ui.Theme.fontFamily;
            context.fillStyle = String(Ui.Theme.subtleText);
            context.textBaseline = "alphabetic";
            const labels = [
                { offset: -12, label: "−12" },
                { offset: -6, label: "−6" },
                { offset: 0, label: "UTC" },
                { offset: 6, label: "+6" },
                { offset: 12, label: "+12" },
                { offset: 14, label: "+14" }
            ];
            labels.forEach(function (entry) {
                const x = Visuals.timezonePosition(entry.offset * 3600) * width;
                context.textAlign = entry.offset === -12 ? "left"
                    : (entry.offset === 14 ? "right" : "center");
                context.fillText(entry.label, x, height - 6);
            });
        }
    }
}
