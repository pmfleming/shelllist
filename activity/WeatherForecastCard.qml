import QtQuick
import Shelllist.Ui as Ui

// Shared frame and range caption ("12H", "7D") for the weather forecasts.
Rectangle {
    required property var weather
    property alias label: caption.text
    property alias labelTopMargin: caption.anchors.topMargin

    width: parent.width
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Ui.ThemeText {
        id: caption
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Ui.Theme.spacingMd
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }
}
