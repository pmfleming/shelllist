pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothGlyphs.js" as BluetoothGlyphs

Item {
    id: root

    required property var device
    readonly property var displayReports: BluetoothBattery.displayReports(device)
    readonly property int indicatorHeight: 166
    readonly property int artworkSize: Math.round((displayReports.length === 1 ? 126 : 108) * 0.68)

    visible: true
    implicitHeight: indicatorHeight

    function ringColor(percentage) {
        if (percentage <= 20)
            return Ui.Theme.danger;
        if (percentage <= 35)
            return Ui.Theme.warning;
        return Ui.Theme.active;
    }

    Row {
        id: indicators

        readonly property int itemWidth: Math.min(172, root.width / Math.max(1, root.displayReports.length))

        x: Math.round((parent.width - width) / 2)
        width: itemWidth * root.displayReports.length
        height: root.indicatorHeight
        spacing: 0

        Repeater {
            model: root.displayReports

            delegate: Item {
                id: indicator

                required property var modelData
                readonly property bool batteryAvailable: BluetoothBattery.isValid(modelData)
                readonly property real percentage: batteryAvailable ? modelData.percentage : 0
                readonly property color statusColor: root.ringColor(percentage)
                readonly property string imageSource: BluetoothBattery.imageFor(root.device, modelData)
                readonly property int ringSize: root.displayReports.length === 1 ? 126 : 108

                width: indicators.itemWidth
                height: indicators.height

                Canvas {
                    id: ring

                    x: Math.round((parent.width - width) / 2)
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

                        if (indicator.batteryAvailable && indicator.percentage > 0) {
                            context.strokeStyle = indicator.statusColor;
                            context.beginPath();
                            context.arc(center, center, radius, start, end);
                            context.stroke();
                        }
                    }
                }

                Image {
                    x: ring.x + Math.round((ring.width - width) / 2)
                    y: ring.y + Math.round((ring.height - height) / 2)
                    width: root.artworkSize
                    height: root.artworkSize
                    source: indicator.imageSource
                    sourceSize.width: 180
                    sourceSize.height: 180
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    visible: indicator.imageSource.length > 0
                    opacity: root.device.battery_last_known ? 0.78 : 1.0
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
                    visible: indicator.batteryAvailable
                    x: ring.x + Math.round((ring.width - width) / 2)
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
                    visible: indicator.batteryAvailable
                    x: Math.round(Ui.Theme.spacingSm / 2)
                    y: ring.y + ring.height + Ui.Theme.spacingSm
                    width: parent.width - Ui.Theme.spacingSm
                    text: indicator.percentage + "%"
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
