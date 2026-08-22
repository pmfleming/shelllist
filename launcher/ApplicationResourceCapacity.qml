import QtQuick
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Rectangle {
    id: capacity

    required property string label
    required property var segments
    property string valueText: Resources.bytes(total)
    property string detailText: ""
    property color accentColor: segments.length > 0 ? segments[0].color : Ui.Theme.mutedText
    property real maximum: total
    property bool available: true
    property real uiScale: 1
    readonly property real total: (segments || []).reduce(function (sum, segment) {
        return sum + Math.max(0, Number(segment.value || 0));
    }, 0)

    height: Math.round(92 * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.mix(Ui.Theme.surfaceRaised, accentColor, Ui.Theme.dark ? 0.12 : 0.07)
    border.width: 0

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 8
        text: capacity.label
        color: Ui.Theme.mutedText
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 26
        text: capacity.available ? capacity.valueText : ""
        color: capacity.accentColor
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightBold
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 51
        text: capacity.available ? capacity.detailText : "No measurements"
        color: Ui.Theme.subtleText
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
    }

    Canvas {
        id: bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.bottomMargin: 10
        height: Math.max(6, Math.round(7 * capacity.uiScale))
        antialiasing: true

        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.fillStyle = Ui.Theme.withAlpha(Ui.Theme.input, capacity.available ? 0.9 : 0.5);
            context.fillRect(0, 0, width, height);
            if (!capacity.available || capacity.maximum <= 0)
                return;
            let left = 0;
            capacity.segments.forEach(function (segment) {
                const segmentWidth = Math.max(0, Number(segment.value || 0))
                    / capacity.maximum * width;
                context.fillStyle = segment.color;
                context.fillRect(left, 0, Math.min(width - left, segmentWidth), height);
                left += segmentWidth;
            });
        }
    }

    onSegmentsChanged: bar.requestPaint()
    onMaximumChanged: bar.requestPaint()
    onAvailableChanged: bar.requestPaint()
    onWidthChanged: bar.requestPaint()
}
