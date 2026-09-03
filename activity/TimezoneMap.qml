import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: map

    required property date now
    property int offsetSeconds: 0
    property string timezoneName: ""
    property string abbreviation: ""

    radius: Ui.Theme.controlRadius
    color: Ui.Theme.surfaceRaised
    border.color: Ui.Theme.border
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "World map of geographic timezone areas. "
        + (timezoneName || "Selected timezone") + ", "
        + Visuals.utcOffset(offsetSeconds) + ", local time "
        + Visuals.localTime(now.getTime(), offsetSeconds)

    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: Ui.Theme.spacingSm
        anchors.topMargin: Ui.Theme.spacingSm
        text: "WORLD TIME ZONES"
        color: Ui.Theme.mutedText
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeCaption
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Ui.Theme.spacingSm
        anchors.topMargin: 5
        width: selectedLabel.implicitWidth + Ui.Theme.spacingMd
        height: 22
        radius: 4
        color: Ui.Theme.selected
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.55)

        Text {
            id: selectedLabel
            anchors.centerIn: parent
            text: (map.abbreviation || Visuals.utcOffset(map.offsetSeconds))
                + "  ·  " + Visuals.localTime(map.now.getTime(), map.offsetSeconds)
            color: Ui.Theme.accent
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
            font.weight: Ui.Theme.fontWeightDemiBold
        }
    }

    Image {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        anchors.topMargin: 34
        source: Qt.resolvedUrl("assets/timezones/world-time-zones.svg")
        fillMode: Image.PreserveAspectFit
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        smooth: true
        mipmap: true
        asynchronous: true
        Accessible.ignored: true
    }
}
