pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothGlyphs.js" as BluetoothGlyphs

Item {
    id: root

    required property var device
    readonly property var reports: BluetoothBattery.visualOrdered(device.battery || [])
    readonly property int indicatorHeight: 166

    visible: reports.length > 0
    implicitHeight: visible ? indicatorHeight : 0

    function componentName(report) {
        const component = String((report && report.component) || "").toLowerCase();
        if (component === "left")
            return "Left";
        if (component === "right")
            return "Right";
        if (component === "case")
            return "Case";
        return (report && (report.label || report.component)) || "Battery";
    }

    function ringColor(percentage) {
        if (percentage <= 20)
            return Ui.Theme.danger;
        if (percentage <= 35)
            return Ui.Theme.warning;
        return Ui.Theme.active;
    }

    function imageFor(report) {
        const component = String((report && report.component) || "").toLowerCase();
        if (component === "left")
            return "assets/audio/left-earbud.png";
        if (component === "right")
            return "assets/audio/right-earbud.png";
        if (component === "case")
            return "assets/audio/charging-case.png";

        const icon = String(device.icon || "").toLowerCase();
        if (icon.indexOf("headset") >= 0)
            return "assets/audio/headset.png";
        if (icon.indexOf("headphones") >= 0)
            return "assets/audio/headphones.png";

        const services = (device.services || []).map(function (service) {
            return String(service.label || "").toLowerCase();
        }).join(" ");
        if (services.indexOf("handsfree") >= 0 || services.indexOf("headset") >= 0)
            return "assets/audio/headset.png";
        if (services.indexOf("audio sink") >= 0)
            return "assets/audio/headphones.png";
        return "";
    }

    Row {
        id: indicators

        readonly property int itemWidth: Math.min(172, root.width / Math.max(1, root.reports.length))

        anchors.horizontalCenter: parent.horizontalCenter
        width: itemWidth * root.reports.length
        height: root.indicatorHeight
        spacing: 0

        Repeater {
            model: root.reports

            delegate: Item {
                id: indicator

                required property var modelData
                readonly property real percentage: modelData.percentage
                readonly property color statusColor: root.ringColor(percentage)
                readonly property string imageSource: root.imageFor(modelData)
                readonly property int ringSize: root.reports.length === 1 ? 126 : 108

                width: indicators.itemWidth
                height: indicators.height

                Canvas {
                    id: ring

                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 12
                    width: indicator.ringSize
                    height: indicator.ringSize
                    antialiasing: true

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: indicator
                        function onPercentageChanged() { ring.requestPaint(); }
                        function onStatusColorChanged() { ring.requestPaint(); }
                    }

                    onPaint: {
                        const context = getContext("2d");
                        const lineWidth = Math.max(8, width * 0.085);
                        const radius = (width - lineWidth) / 2;
                        const center = width / 2;
                        const start = -Math.PI / 2;
                        const end = start + Math.PI * 2 * Math.max(0, Math.min(100, indicator.percentage)) / 100;

                        context.clearRect(0, 0, width, height);
                        context.lineWidth = lineWidth;
                        context.lineCap = "round";
                        context.strokeStyle = Ui.Theme.withAlpha(Ui.Theme.mutedText, 0.22);
                        context.beginPath();
                        context.arc(center, center, radius, 0, Math.PI * 2);
                        context.stroke();

                        if (indicator.percentage > 0) {
                            context.strokeStyle = indicator.statusColor;
                            context.beginPath();
                            context.arc(center, center, radius, start, end);
                            context.stroke();
                        }
                    }
                }

                Image {
                    anchors.centerIn: ring
                    width: indicator.ringSize * 0.68
                    height: indicator.ringSize * 0.68
                    source: indicator.imageSource
                    sourceSize.width: 180
                    sourceSize.height: 180
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    visible: indicator.imageSource.length > 0
                }

                Text {
                    anchors.centerIn: ring
                    visible: indicator.imageSource.length === 0
                    text: indicator.modelData.component === "main"
                        ? BluetoothGlyphs.forDevice(root.device)
                        : BluetoothGlyphs.forBattery(indicator.modelData)
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Math.round(indicator.ringSize * 0.38)
                }

                Rectangle {
                    anchors.horizontalCenter: ring.horizontalCenter
                    y: 0
                    width: 34
                    height: 34
                    radius: width / 2
                    color: indicator.statusColor
                    border.width: 3
                    border.color: Ui.Theme.window

                    Text {
                        anchors.centerIn: parent
                        text: "󰁹"
                        color: Ui.Theme.readableOn(indicator.statusColor)
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: 17
                    }
                }

                Text {
                    anchors.top: ring.bottom
                    anchors.topMargin: Ui.Theme.spacingSm
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - Ui.Theme.spacingSm
                    text: root.componentName(indicator.modelData) + ": " + indicator.percentage + "%"
                    color: Ui.Theme.text
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeHeading
                    font.weight: Ui.Theme.fontWeightDemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
