import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Rectangle {
    id: donut

    required property string label
    required property var segments
    property bool available: true
    property real uiScale: 1
    readonly property real total: segments.reduce(function (sum, segment) {
        return sum + Math.max(0, Number(segment.value || 0));
    }, 0)
    property string centerText: Resources.bytes(total)

    height: Math.round(126 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    border.width: 1

    Canvas {
        id: chart
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(10 * donut.uiScale)
        width: Math.round(72 * donut.uiScale)
        height: width
        antialiasing: true
        onPaint: {
            const context = getContext("2d");
            context.reset();
            const center = width / 2;
            const radius = width * 0.38;
            const thickness = Math.max(7, width * 0.13);
            context.lineWidth = thickness;
            context.lineCap = "butt";
            if (!donut.available || donut.total <= 0) {
                context.beginPath();
                context.arc(center, center, radius, 0, Math.PI * 2);
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.13);
                context.stroke();
                context.save();
                context.beginPath();
                context.arc(center, center, radius + thickness / 2, 0, Math.PI * 2);
                context.arc(center, center, radius - thickness / 2, 0, Math.PI * 2, true);
                context.clip();
                context.beginPath();
                for (let x = -height; x < width + height; x += 7) {
                    context.moveTo(x, height);
                    context.lineTo(x + height, 0);
                }
                context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.3);
                context.lineWidth = 1;
                context.stroke();
                context.restore();
                return;
            }
            let angle = -Math.PI / 2;
            donut.segments.forEach(function (segment) {
                const share = Math.max(0, Number(segment.value || 0)) / donut.total;
                const next = angle + share * Math.PI * 2;
                context.beginPath();
                context.arc(center, center, radius, angle, next);
                context.strokeStyle = segment.color;
                context.stroke();
                angle = next;
            });
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: labelText.top
        anchors.bottomMargin: 1
        text: donut.available ? donut.centerText : ""
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        id: labelText
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        leftPadding: 4
        rightPadding: 4
        text: donut.label
        color: Ui.Theme.mutedText
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    onSegmentsChanged: chart.requestPaint()
    onAvailableChanged: chart.requestPaint()
}
