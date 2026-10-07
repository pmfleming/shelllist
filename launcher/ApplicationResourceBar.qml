pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

// A zero-based quantity bar, never a capacity gauge or an interactive slider.
Item {
    id: bar
    property real fraction: 0
    property color color: Ui.Theme.resourceDisk
    property bool patterned: false
    property real uiScale: 1
    readonly property real filledWidth: width * (isFinite(fraction) ? Math.min(1, Math.max(0, fraction)) : 0)
    implicitHeight: Math.round(10 * uiScale)
    Accessible.ignored: true

    Rectangle {
        width: 1
        height: parent.height
        color: Ui.Theme.border
    }
    Rectangle {
        width: bar.filledWidth
        height: parent.height
        color: bar.color
    }
    Canvas {
        id: stripes
        width: bar.filledWidth
        height: parent.height
        visible: bar.patterned && width > 0
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: requestPaint()
        Connections {
            target: bar
            function onUiScaleChanged(): void { stripes.requestPaint(); }
            function onColorChanged(): void { stripes.requestPaint(); }
        }
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.strokeStyle = Ui.Theme.withAlpha("#000000", 0.45);
            context.lineWidth = 2 * bar.uiScale;
            context.beginPath();
            for (let x = -height; x < width; x += 6 * bar.uiScale) {
                context.moveTo(x, height);
                context.lineTo(x + height, 0);
            }
            context.stroke();
        }
    }
}
