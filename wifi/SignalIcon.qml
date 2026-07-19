import QtQuick
import Shelllist.Ui

Canvas {
    property int level: 3
    property color iconColor: Theme.accent
    property color inactiveColor: Theme.withAlpha(Theme.mutedText, 0.62)

    implicitWidth: 24
    implicitHeight: 22
    antialiasing: true

    onLevelChanged: requestPaint()
    onIconColorChanged: requestPaint()
    onInactiveColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    function drawArcs(context, count, centerX, centerY, radiusStep) {
        for (let current = 1; current <= count; ++current) {
            context.beginPath();
            context.arc(centerX, centerY, radiusStep * current, Math.PI * 1.18, Math.PI * 1.82);
            context.stroke();
        }
    }

    onPaint: {
        const context = getContext("2d");
        const scale = Math.min(width, height);
        const centerX = width / 2;
        const centerY = height * 0.78;
        context.clearRect(0, 0, width, height);
        context.lineWidth = Math.max(1.5, scale * 0.09);
        context.lineCap = "round";
        context.strokeStyle = inactiveColor;
        drawArcs(context, 3, centerX, centerY, scale * 0.18);

        context.fillStyle = iconColor;
        context.beginPath();
        context.arc(centerX, centerY, Math.max(1.6, scale * 0.09), 0, Math.PI * 2);
        context.fill();
        context.strokeStyle = iconColor;
        drawArcs(context, Math.max(1, Math.min(3, level)), centerX, centerY, scale * 0.18);
    }
}
