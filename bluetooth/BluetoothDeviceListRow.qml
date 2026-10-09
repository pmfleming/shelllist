import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.ResultRow {
    id: row

    required property var resultData

    readonly property var device: resultData.payload || ({})
    readonly property bool hasSignal: BluetoothFlow.hasSignal(device)
    readonly property bool relativeSignal: BluetoothFlow.hasRelativeSignal(device)
    readonly property int signalStrength: hasSignal ? Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) : 0
    readonly property int signalLevel: BluetoothFlow.signalLevel(device)
    readonly property bool signalLive: !!device.signal_live
    accessibleName: resultData.title + ". " + resultData.subtitle + ". Signal: " + BluetoothFlow.signalLabel(device)
    readonly property color signalColor: !hasSignal || relativeSignal ? Ui.Theme.mutedText : (signalStrength >= 67 ? Ui.Theme.active : (signalStrength >= 34 ? Ui.Theme.warning : Ui.Theme.danger))

    Ui.ThemeText {
        objectName: "bluetoothSignalValue"
        Layout.preferredWidth: row.scaled(44)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: BluetoothFlow.signalValue(row.device)
        color: row.signalColor
        opacity: row.signalLive ? 1 : 0.58
        font.pixelSize: Ui.Theme.metadataSize
        font.weight: Font.Medium
    }

    Ui.SignalIcon {
        objectName: "bluetoothSignalIcon"
        Layout.preferredWidth: row.scaled(24)
        Layout.preferredHeight: row.scaled(20)
        level: row.signalLevel
        iconColor: row.signalColor
        opacity: row.relativeSignal ? 0 : (row.signalLive ? 1 : 0.58)
    }

    leadingIcon: resultData.icon || "󰂯"
    leadingIconColor: device.blocked ? Ui.Theme.danger : (device.connected ? Ui.Theme.active : Ui.Theme.mutedText)

    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle
        titleWeight: row.device.connected ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }
}
