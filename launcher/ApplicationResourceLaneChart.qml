pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: chart

    required property string title
    required property var points
    required property var lanes
    required property double rangeStartMilliseconds
    required property double rangeEndMilliseconds
    property double maximumGapMilliseconds: 30000
    property real uiScale: 1
    readonly property var timestamps: (points || []).map(function (point) {
        const value = Number(point.timestamp_ms || 0);
        return isFinite(value) && value > 0 ? value : 0;
    })

    height: Math.round((38 + lanes.length * 38) * uiScale)
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border
    border.width: 1

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 11
        anchors.topMargin: 8
        text: chart.title
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Math.round(31 * chart.uiScale)
        spacing: Math.round(3 * chart.uiScale)

        Repeater {
            model: chart.lanes
            delegate: Item {
                id: lane
                required property var modelData
                width: parent.width
                height: Math.round(35 * chart.uiScale)

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(82 * chart.uiScale)
                    text: lane.modelData.label
                    color: Ui.Theme.mutedText
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }

                Canvas {
                    id: plot
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(98 * chart.uiScale)
                    anchors.right: parent.right
                    anchors.rightMargin: Math.round(72 * chart.uiScale)
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    antialiasing: false

                    function xFor(timestamp) {
                        return (timestamp - chart.rangeStartMilliseconds)
                            / Math.max(1, chart.rangeEndMilliseconds - chart.rangeStartMilliseconds) * width;
                    }
                    function hatch(left, right) {
                        const context = getContext("2d");
                        const start = Math.max(0, left);
                        const end = Math.min(width, right);
                        if (end <= start) return;
                        context.fillStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.055);
                        context.fillRect(start, 0, end - start, height);
                        context.save();
                        context.beginPath();
                        context.rect(start, 0, end - start, height);
                        context.clip();
                        context.beginPath();
                        for (let x = start - height; x < end + height; x += 7) {
                            context.moveTo(x, height);
                            context.lineTo(x + height, 0);
                        }
                        context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.22);
                        context.lineWidth = 1;
                        context.stroke();
                        context.restore();
                    }
                    function drawGaps() {
                        const valid = chart.timestamps.filter(function (timestamp) {
                            return timestamp >= chart.rangeStartMilliseconds
                                && timestamp <= chart.rangeEndMilliseconds;
                        });
                        const radius = chart.maximumGapMilliseconds / 2;
                        if (lane.modelData.unavailable || valid.length === 0) {
                            hatch(0, width);
                            return;
                        }
                        hatch(0, xFor(Math.max(chart.rangeStartMilliseconds, valid[0] - radius)));
                        for (let index = 1; index < valid.length; ++index) {
                            if (valid[index] - valid[index - 1] > chart.maximumGapMilliseconds)
                                hatch(xFor(valid[index - 1] + radius), xFor(valid[index] - radius));
                        }
                        hatch(xFor(Math.min(chart.rangeEndMilliseconds,
                            valid[valid.length - 1] + radius)), width);
                    }
                    Connections {
                        target: chart
                        function onPointsChanged() { plot.requestPaint(); }
                        function onRangeStartMillisecondsChanged() { plot.requestPaint(); }
                        function onRangeEndMillisecondsChanged() { plot.requestPaint(); }
                    }

                    onPaint: {
                        const context = getContext("2d");
                        context.reset();
                        context.fillStyle = Ui.Theme.input;
                        context.fillRect(0, 0, width, height);
                        drawGaps();
                        if (lane.modelData.unavailable)
                            return;
                        const descriptors = lane.modelData.series || [];
                        const maximum = Math.max(1, Number(lane.modelData.maximum || 0),
                            chart.points.reduce(function (largest, point) {
                                return descriptors.reduce(function (next, descriptor) {
                                    const value = Number(point[descriptor.metric]);
                                    return isFinite(value) ? Math.max(next, value) : next;
                                }, largest);
                            }, 0));
                        const bucketWidth = Math.max(1, chart.maximumGapMilliseconds
                            / Math.max(1, chart.rangeEndMilliseconds - chart.rangeStartMilliseconds) * width);
                        chart.points.forEach(function (point, pointIndex) {
                            const timestamp = chart.timestamps[pointIndex];
                            if (timestamp < chart.rangeStartMilliseconds || timestamp > chart.rangeEndMilliseconds)
                                return;
                            const groupWidth = Math.max(1, bucketWidth * 0.82);
                            const barWidth = Math.max(0.5, groupWidth / Math.max(1, descriptors.length));
                            descriptors.forEach(function (descriptor, seriesIndex) {
                                const value = Number(point[descriptor.metric]);
                                if (!isFinite(value) || value < 0) return;
                                const barHeight = Math.min(height, value / maximum * height);
                                context.fillStyle = Ui.Theme.withAlpha(descriptor.color, 0.82);
                                context.fillRect(xFor(timestamp) - groupWidth / 2 + seriesIndex * barWidth,
                                    height - barHeight, Math.max(0.5, barWidth - 0.35), barHeight);
                            });
                        });
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(56 * chart.uiScale)
                    text: lane.modelData.unavailable ? "" : lane.modelData.valueText
                    color: lane.modelData.color || Ui.Theme.accent
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                    font.weight: Ui.Theme.fontWeightDemiBold
                }
            }
        }
    }

}
