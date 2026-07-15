import QtQuick
import QtQuick.Layouts
import "."

Rectangle {
    id: row

    required property int index
    required property var modelData
    property bool active: false
    property string name: ""
    property int selectedIndex: 0
    property bool detailsOpen: false
    property bool connecting: false
    property int progressTick: 0
    property real rowHeight: 52

    readonly property bool selected: index === selectedIndex
    readonly property bool securedNetwork: modelData.security !== "--"
        || (Number(modelData.flags) || 0) > 0
        || (Number(modelData.wpa_flags) || 0) > 0
        || (Number(modelData.rsn_flags) || 0) > 0
    readonly property bool openNetwork: !securedNetwork
    readonly property int signalStrength: Math.max(0, Math.min(100, Number(modelData.strength) || 0))
    readonly property int signalBarCount: signalStrength >= 67 ? 3 : (signalStrength >= 34 ? 2 : 1)
    readonly property color signalColor: signalStrength >= 67 ? Theme.active : (signalStrength >= 34 ? Theme.warning : Theme.danger)
    readonly property real density: Math.max(0.86, Math.min(1.08, rowHeight / 52))
    readonly property var spinnerFrames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

    signal picked(int rowIndex)
    signal connectRequested
    signal detailsToggled(int rowIndex)

    width: ListView.view.width
    height: rowHeight
    radius: selected ? Theme.cardRadius : 0
    color: selected ? Theme.selected : "transparent"
    border.color: selected ? Theme.strongBorder : "transparent"
    border.width: selected ? 1 : 0

    Rectangle {
        visible: !row.selected
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        height: 1
        color: Theme.mix(Theme.border, Theme.text, 0.14)
        opacity: 0.85
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 16
        spacing: 10

        Text {
            Layout.preferredWidth: 44
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            text: row.signalStrength + "%"
            color: row.signalColor
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(13 * row.density)
            font.weight: Font.Medium
        }

        Item {
            Layout.preferredWidth: 27
            Layout.fillHeight: true

            SignalIcon {
                anchors.centerIn: parent
                width: 24
                height: 20
                level: row.signalBarCount
                iconColor: row.signalColor
            }
        }

        Text {
            Layout.preferredWidth: 18
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: row.connecting
                ? row.spinnerFrames[row.progressTick % row.spinnerFrames.length]
                : (row.openNetwork ? "" : "󰌾")
            color: row.connecting ? Theme.accent : Theme.mutedText
            font.family: row.connecting ? Theme.fontFamily : Theme.iconFontFamily
            font.pixelSize: Math.round(13 * row.density)
        }

        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            text: row.connecting ? row.name + " — connecting…" : row.name
            color: row.connecting ? Theme.accent : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(14 * row.density)
            font.bold: row.active || row.connecting
            elide: Text.ElideRight
        }

        Text {
            Layout.preferredWidth: 18
            Layout.fillHeight: true
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: "󰅂"
            color: row.selected ? Theme.accent : Theme.mutedText
            font.family: Theme.iconFontFamily
            font.pixelSize: Math.round(17 * row.density)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: row.detailsToggled(row.index)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: 38
        onClicked: row.picked(row.index)
        onDoubleClicked: row.connectRequested()
    }
}
