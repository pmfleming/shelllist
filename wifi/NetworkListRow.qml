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
    property bool captivePortal: false
    property string networkTypeIcon: ""
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

    GlyphLabel {
        Layout.preferredWidth: row.scaled(18)
        Layout.fillHeight: true
        glyph: row.connecting ? row.spinnerFrames[row.progressTick % row.spinnerFrames.length] : row.networkTypeIcon
        color: row.connecting ? Theme.accent : (row.captivePortal ? Theme.warning : Theme.mutedText)
        font.family: row.connecting ? Theme.fontFamily : Theme.iconFontFamily
        font.pixelSize: Math.round(Theme.fontSizeLabel * row.density)
    }

    ResultLabel {
        title: row.connecting ? row.name + " — connecting…" : row.name
        titleColor: row.connecting ? Theme.accent : Theme.text
        titlePixelSize: Math.round(Theme.fontSizeBody * row.density)
        titleWeight: row.active || row.connecting ? Theme.fontWeightBold : Theme.fontWeightRegular
        uiScale: row.density
        singleLine: true
    }
}
