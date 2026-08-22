import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: badge

    property string text: ""
    property string tone: "normal"
    readonly property color toneColor: tone === "warning" ? Ui.Theme.warning
        : tone === "accent" ? Ui.Theme.accent : Ui.Theme.mutedText

    width: label.implicitWidth + 16
    height: 25
    radius: height / 2
    color: Ui.Theme.withAlpha(toneColor, tone === "normal" ? 0.08 : 0.14)
    border.color: Ui.Theme.withAlpha(toneColor, 0.42)
    border.width: 1

    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: badge.toneColor
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }
}
