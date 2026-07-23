import QtQuick
import QtQuick.Layouts
import Shelllist.Ui

ResultRow {
    id: row

    required property var resultData
    readonly property var result: resultData
    readonly property var network: result.payload || ({})
    property bool active: false
    property string name: ""
    property bool connecting: false
    property int progressTick: 0

    readonly property bool securedNetwork: network.security !== "--" || (Number(network.flags) || 0) > 0 || (Number(network.wpa_flags) || 0) > 0 || (Number(network.rsn_flags) || 0) > 0
    readonly property bool openNetwork: !securedNetwork
    readonly property int signalStrength: Math.max(0, Math.min(100, Number(network.strength) || 0))
    readonly property int signalBarCount: signalStrength >= 67 ? 3 : (signalStrength >= 34 ? 2 : 1)
    readonly property color signalColor: signalStrength >= 67 ? Theme.active : (signalStrength >= 34 ? Theme.warning : Theme.danger)
    readonly property real density: Math.max(Theme.listDensityMinimum, Math.min(Theme.listDensityMaximum, rowHeight / Theme.listRowHeight))
    readonly property var spinnerFrames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    uiScale: density

    Text {
        Layout.preferredWidth: row.scaled(44)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        text: row.signalStrength + "%"
        color: row.signalColor
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSizeLabel * row.density)
        font.weight: Font.Medium
    }

    Item {
        Layout.preferredWidth: row.scaled(27)
        Layout.fillHeight: true

        SignalIcon {
            anchors.centerIn: parent
            width: row.scaled(24)
            height: row.scaled(20)
            level: row.signalBarCount
            iconColor: row.signalColor
        }
    }

    Text {
        Layout.preferredWidth: row.scaled(18)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: row.connecting ? row.spinnerFrames[row.progressTick % row.spinnerFrames.length] : (row.openNetwork ? "" : "󰌾")
        color: row.connecting ? Theme.accent : Theme.mutedText
        font.family: row.connecting ? Theme.fontFamily : Theme.iconFontFamily
        font.pixelSize: Math.round(Theme.fontSizeLabel * row.density)
    }

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        text: row.connecting ? row.name + " — connecting…" : row.name
        color: row.connecting ? Theme.accent : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Math.round(Theme.fontSizeBody * row.density)
        font.bold: row.active || row.connecting
        elide: Text.ElideRight
    }
}
