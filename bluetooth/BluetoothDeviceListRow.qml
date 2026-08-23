import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BluetoothFlow.js" as BluetoothFlow

Ui.ResultRow {
    id: row

    required property var resultData

    readonly property var device: resultData.payload || ({})
    readonly property bool hasSignal: BluetoothFlow.hasSignal(device)
    readonly property int signalStrength: hasSignal ? Math.max(0, Math.min(100, Math.round(Number(device.signal_strength) || 0))) : 0
    readonly property int signalLevel: BluetoothFlow.signalLevel(device)
    readonly property bool signalLive: !!device.signal_live
    accessibleName: resultData.title + ". " + resultData.subtitle
    readonly property color signalColor: !hasSignal ? Ui.Theme.mutedText : (signalStrength >= 67 ? Ui.Theme.active : (signalStrength >= 34 ? Ui.Theme.warning : Ui.Theme.danger))

    Text {
        Layout.preferredWidth: row.scaled(44)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: row.hasSignal ? row.signalStrength + "%" : "—"
        color: row.signalColor
        opacity: row.signalLive ? 1 : 0.58
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(10, row.scaled(Ui.Theme.fontSizeCaption))
        font.weight: Font.Medium
    }

    Ui.SignalIcon {
        Layout.preferredWidth: row.scaled(24)
        Layout.preferredHeight: row.scaled(20)
        level: row.signalLevel
        iconColor: row.signalColor
        opacity: row.signalLive ? 1 : 0.58
    }

    Ui.GlyphLabel {
        Layout.preferredWidth: row.scaled(28)
        Layout.fillHeight: true
        glyph: row.resultData.icon || "󰂯"
        color: row.device.blocked ? Ui.Theme.danger
            : (row.device.connected ? Ui.Theme.active : Ui.Theme.mutedText)
        font.pixelSize: Math.max(Ui.Theme.iconSize, row.scaled(Ui.Theme.fontSizeTitle))
    }

    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle
        titleWeight: row.device.connected ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }
}
