pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BluetoothBattery.js" as BluetoothBattery
import "BluetoothGlyphs.js" as BluetoothGlyphs

Item {
    id: root
    objectName: "bluetoothBatteryStatus"

    required property var device
    property bool active: true
    readonly property bool connected: !!device.connected
    // This is a service-readiness wait, not evidence of an active retry or
    // support for every component. Resolved-but-unreported stays unknown.
    readonly property bool waitingForServices: connected && device.services_resolved === false
    readonly property var displayReports: BluetoothBattery.displayReports(device)
    readonly property var overallReport: displayReports.some(function (report) {
        return report.component === "main";
    }) ? null : BluetoothBattery.ordered(device.battery || []).find(function (report) {
        return report.component === "main";
    }) || null
    readonly property bool batteryLive: !!device.connected && !device.battery_last_known
    readonly property int indicatorHeight: 166
    readonly property int ringSize: displayReports.length === 1 ? 126 : 108
    readonly property int artworkSize: Math.round(ringSize * 0.68)
    readonly property real percentageY: 12 + ringSize + Ui.Theme.spacingSm
    readonly property real percentageBottom: percentageY + Math.ceil(percentageMetrics.height)

    visible: true
    implicitHeight: indicatorHeight + (overallReport ? overallPercentage.implicitHeight + Ui.Theme.spacingSm : 0)

    Ui.ThemeText {
        id: overallPercentage
        objectName: "overallBatteryPercentage"
        visible: !!root.overallReport
        y: root.indicatorHeight
        width: parent.width
        text: root.overallReport ? root.overallReport.percentage + "%" : ""
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
        opacity: root.batteryLive ? 1.0 : Ui.Theme.disabledOpacity
        Accessible.name: "Battery " + text
    }

    TextMetrics {
        id: percentageMetrics
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
        text: "100%"
    }

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
                readonly property bool batteryPending: !batteryAvailable && root.waitingForServices
                readonly property real percentage: batteryAvailable ? modelData.percentage : 0
                readonly property bool charging: !!root.device.battery_live && modelData.charging === true
                Accessible.role: Accessible.StaticText
                Accessible.name: (root.connected ? qsTr("Device connected. ") : "") + (BluetoothBattery.compactLabel(modelData) || qsTr("Battery")) + " " + (batteryAvailable ? percentage + "%" : batteryPending ? qsTr("Waiting for battery details: Bluetooth services unresolved") : qsTr("unavailable")) + (charging ? qsTr(" charging") : "")
                readonly property color statusColor: batteryAvailable ? root.ringColor(percentage) : Ui.Theme.active
                readonly property string imageSource: BluetoothBattery.imageFor(root.device, modelData)
                readonly property int ringSize: root.ringSize

                width: indicators.itemWidth
                height: indicators.height

                Canvas {
                    id: ring

                    x: Math.round((parent.width - width) / 2)
                    y: 12
                    width: indicator.ringSize
                    height: indicator.ringSize
                    antialiasing: true
                    opacity: root.connected ? 1.0 : Ui.Theme.disabledOpacity

                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()

                    Connections {
                        target: indicator
                        function onPercentageChanged() {
                            ring.requestPaint();
                        }
                        function onStatusColorChanged() {
                            ring.requestPaint();
                        }
                    }
                    Connections {
                        target: root
                        function onConnectedChanged() {
                            ring.requestPaint();
                        }
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
                        context.strokeStyle = Ui.Theme.withAlpha(root.connected ? Ui.Theme.active : Ui.Theme.mutedText, 0.22);
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
                    objectName: "batteryArtwork-" + indicator.modelData.component
                    x: ring.x + Math.round((ring.width - width) / 2)
                    y: ring.y + Math.round((ring.height - height) / 2)
                    width: root.artworkSize
                    height: root.artworkSize
                    source: indicator.imageSource
                    asynchronous: true
                    sourceSize.width: 180
                    sourceSize.height: 180
                    fillMode: Image.PreserveAspectFit
                    mipmap: true
                    visible: indicator.imageSource.length > 0
                    opacity: root.device.connected ? 1.0 : 0.78
                }

                Text {
                    anchors.centerIn: ring
                    visible: indicator.imageSource.length === 0
                    text: indicator.modelData.component === "main" ? BluetoothGlyphs.forDevice(root.device) : BluetoothGlyphs.forBattery(indicator.modelData)
                    color: Ui.Theme.mutedText
                    font.family: Ui.Theme.iconFontFamily
                    font.pixelSize: Math.round(indicator.ringSize * 0.38)
                }

                Rectangle {
                    objectName: "batteryBadge-" + indicator.modelData.component
                    visible: root.connected || indicator.batteryAvailable
                    opacity: root.connected ? 1.0 : Ui.Theme.disabledOpacity
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
                        text: indicator.batteryAvailable ? (indicator.charging ? "󰂄" : "󰁹") : "󰂯"
                        Accessible.ignored: true
                        color: Ui.Theme.readableOn(indicator.statusColor)
                        font.family: Ui.Theme.iconFontFamily
                        font.pixelSize: 17
                    }
                }

                Ui.GlyphLabel {
                    id: pending
                    objectName: "batteryPending-" + indicator.modelData.component
                    readonly property bool spinning: visible && root.active && !Ui.Theme.noAnimations
                    visible: indicator.batteryPending
                    x: Math.round((parent.width - width) / 2)
                    y: root.percentageY
                    width: height
                    height: Math.ceil(percentageMetrics.height)
                    glyph: "refresh"
                    color: Ui.Theme.active
                    font.pixelSize: Ui.Theme.fontSizeHeading
                    Accessible.ignored: true

                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Ui.Theme.spinnerDuration
                        loops: Animation.Infinite
                        running: pending.spinning
                    }
                    onSpinningChanged: if (!spinning)
                        rotation = 0
                }

                Ui.ThemeText {
                    objectName: "batteryPercentage-" + indicator.modelData.component
                    visible: !indicator.batteryPending
                    Accessible.ignored: true
                    opacity: root.batteryLive ? 1.0 : Ui.Theme.disabledOpacity
                    x: Math.round(Ui.Theme.spacingSm / 2)
                    y: root.percentageY
                    width: parent.width - Ui.Theme.spacingSm
                    text: indicator.batteryAvailable ? indicator.percentage + "%" : "—"
                    font.pixelSize: Ui.Theme.fontSizeHeading
                    font.weight: Ui.Theme.fontWeightDemiBold
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
