import QtQuick
import "."

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

    onPaint: {
        const context = getContext("2d");
        context.clearRect(0, 0, width, height);
        context.lineWidth = Math.max(1.5, Math.min(width, height) * 0.09);
        context.lineCap = "round";

        const centerX = width / 2;
        const centerY = height * 0.78;
        const dotRadius = Math.max(1.6, Math.min(width, height) * 0.09);
        const radiusStep = Math.min(width, height) * 0.18;

        context.strokeStyle = inactiveColor;
        for (let current = 1; current <= 3; ++current) {
            context.beginPath();
            context.arc(centerX, centerY, radiusStep * current, Math.PI * 1.18, Math.PI * 1.82);
            context.stroke();
        }

        context.fillStyle = iconColor;
        context.beginPath();
        context.arc(centerX, centerY, dotRadius, 0, Math.PI * 2);
        context.fill();

        context.strokeStyle = iconColor;
        const visibleLevels = Math.max(1, Math.min(3, level));
        for (let current = 1; current <= visibleLevels; ++current) {
            context.beginPath();
            context.arc(centerX, centerY, radiusStep * current, Math.PI * 1.18, Math.PI * 1.82);
            context.stroke();
        }
    }
}
