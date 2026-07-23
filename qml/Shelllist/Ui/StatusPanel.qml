import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel

    required property real uiScale
    property string status: ""
    property string icon: ""
    property bool signalIcon: false
    property bool powered: false
    property bool busy: false

    function scaled(value) {
        return Math.round(value * uiScale);
    }

    height: scaled(Theme.statusHeight)
    radius: Theme.cardRadius
    color: Theme.surfaceRaised
    border.color: Theme.border

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: panel.scaled(Theme.contentMargin)
        anchors.rightMargin: panel.scaled(Theme.contentMargin)
        spacing: panel.scaled(Theme.spacingSm)

        Item {
            Layout.preferredWidth: panel.scaled(Theme.iconSize)
            Layout.preferredHeight: panel.scaled(Theme.iconSize)

            SignalIcon {
                visible: panel.signalIcon
                anchors.centerIn: parent
                width: panel.scaled(18)
                height: panel.scaled(16)
                level: 1
                iconColor: panel.powered ? Theme.accent : Theme.mutedText
            }

            Text {
                visible: !panel.signalIcon
                anchors.fill: parent
                text: panel.icon
                color: panel.powered ? Theme.accent : Theme.mutedText
                font.family: Theme.iconFontFamily
                font.pixelSize: Math.max(Theme.iconSizeSmall, panel.scaled(Theme.iconSize))
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Text {
            Layout.fillWidth: true
            text: panel.status
            color: panel.busy ? Theme.accent : Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(Theme.fontSizeCaption, panel.scaled(Theme.fontSizeCaption))
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
    }
}
