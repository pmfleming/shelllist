import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Canvas {
    required property bool daylight
    required property real fraction
    property bool dataAvailable: true
    property string description: ""
    readonly property color trackColor: Ui.Theme.border
    readonly property color sunColor: Ui.Theme.warning
    readonly property color moonColor: Ui.Theme.text
    readonly property color shadowColor: Ui.Theme.mix(Ui.Theme.surface, Ui.Theme.text, 0.12)

    implicitWidth: 56
    implicitHeight: 56
    Accessible.role: Accessible.Graphic
    Accessible.name: description

    onDaylightChanged: requestPaint()
    onFractionChanged: requestPaint()
    onAvailableChanged: requestPaint()
    onDataAvailableChanged: requestPaint()
    onTrackColorChanged: requestPaint()
    onSunColorChanged: requestPaint()
    onMoonColorChanged: requestPaint()
    onShadowColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        context.save();
        context.translate(width / 2, height / 2);
        const radius = Math.min(width, height) / 2 - 4;
        if (radius <= 0) {
            context.restore();
            return;
        }

        if (daylight) {
            // A full revolution represents 24 hours, not progress through today's daylight.
            context.lineWidth = 4;
            context.lineCap = "butt";
            context.strokeStyle = String(trackColor);
            context.beginPath();
            context.arc(0, 0, radius, 0, 2 * Math.PI);
            context.stroke();
            if (dataAvailable) {
                context.strokeStyle = String(sunColor);
                context.beginPath();
                context.arc(0, 0, radius, -Math.PI / 2,
                    -Math.PI / 2 + Math.max(0, Math.min(1, fraction)) * 2 * Math.PI);
                context.stroke();
            }

            context.fillStyle = String(dataAvailable ? sunColor : trackColor);
            context.beginPath();
            context.arc(0, 0, radius * 0.25, 0, 2 * Math.PI);
            context.fill();
            context.strokeStyle = context.fillStyle;
            context.lineWidth = 2;
            context.lineCap = "round";
            context.beginPath();
            for (let ray = 0; ray < 8; ++ray) {
                const angle = ray * Math.PI / 4;
                context.moveTo(Math.cos(angle) * radius * 0.39,
                    Math.sin(angle) * radius * 0.39);
                context.lineTo(Math.cos(angle) * radius * 0.54,
                    Math.sin(angle) * radius * 0.54);
            }
            context.stroke();
        } else {
            context.fillStyle = String(shadowColor);
            context.beginPath();
            context.arc(0, 0, radius, 0, 2 * Math.PI);
            context.fill();

            // Trace the curved terminator rather than using a fixed crescent glyph.
            context.beginPath();
            const steps = 64;
            for (let step = 0; step <= steps; ++step) {
                const y = -1 + 2 * step / steps;
                const bounds = Visuals.moonLitBounds(fraction, y);
                if (step === 0)
                    context.moveTo(bounds.right * radius, y * radius);
                else
                    context.lineTo(bounds.right * radius, y * radius);
            }
            for (let step = steps; step >= 0; --step) {
                const y = -1 + 2 * step / steps;
                context.lineTo(Visuals.moonLitBounds(fraction, y).left * radius, y * radius);
            }
            context.closePath();
            context.fillStyle = String(moonColor);
            context.fill();
            context.beginPath();
            context.arc(0, 0, radius, 0, 2 * Math.PI);
            context.strokeStyle = String(trackColor);
            context.lineWidth = 1;
            context.stroke();
        }
        context.restore();
    }
}
