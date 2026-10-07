import QtQuick
import Shelllist.Ui as Ui

// Shared frame and range caption ("12H", "7D") for the weather forecasts.
Rectangle {
    id: card
    required property var weather
    property bool hasData: true
    property bool updating: false
    property bool active: true
    property string emptyText: qsTr("No forecast available")
    property alias label: caption.text
    property alias labelTopMargin: caption.anchors.topMargin

    width: parent.width
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.surface
    border.color: Ui.Theme.border

    Ui.ContentState {
        objectName: "forecastContentState"
        anchors.fill: parent
        anchors.topMargin: 24
        visible: !card.hasData
        compact: true
        active: card.active
        icon: "cloud"
        kind: card.weather.error ? "unavailable" : card.updating ? "loading" : "empty"
        text: card.weather.error || (card.updating ? qsTr("Updating forecast…") : card.emptyText)
    }

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
