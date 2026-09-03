import QtQuick
import Shelllist.Ui as Ui
import "TimezoneGeometry.js" as Geometry
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: map

    required property date now
    property int offsetSeconds: 0
    property string timezoneName: ""
    property string abbreviation: ""
    property real latitude: 0
    property real longitude: 0
    property bool hasCoordinates: false
    readonly property string selectedZonePath: Geometry.pathFor(timezoneName)

    function selectedZoneSource(): string {
        if (selectedZonePath.length === 0)
            return "";
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 720 360'>"
            + "<path d='" + selectedZonePath + "' fill='" + String(Ui.Theme.accent)
            + "' fill-opacity='.48' stroke='" + String(Ui.Theme.text)
            + "' stroke-width='1.8' vector-effect='non-scaling-stroke'/></svg>";
        return "data:image/svg+xml," + encodeURIComponent(svg);
    }

    radius: Ui.Theme.controlRadius
    color: Ui.Theme.surfaceRaised
    border.color: Ui.Theme.border
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "World map of geographic timezone areas. "
        + (timezoneName || "Selected timezone") + " is highlighted, "
        + Visuals.utcOffset(offsetSeconds) + ", local time "
        + Visuals.localTime(now.getTime(), offsetSeconds)
        + (hasCoordinates ? ". Location marked on the map" : "")

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

    Item {
        id: mapViewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        anchors.topMargin: 34

        Image {
            id: baseMap
            anchors.fill: parent
            source: Qt.resolvedUrl("assets/timezones/world-time-zones.svg")
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            smooth: true
            mipmap: true
            asynchronous: true
            Accessible.ignored: true
        }

        Image {
            anchors.fill: parent
            source: map.selectedZoneSource()
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            smooth: true
            mipmap: true
            asynchronous: false
            visible: map.selectedZonePath.length > 0
            Accessible.ignored: true
        }

        Rectangle {
            id: locationMarker
            visible: map.hasCoordinates && baseMap.status === Image.Ready
            x: (baseMap.width - baseMap.paintedWidth) / 2
                + (Math.max(-180, Math.min(180, map.longitude)) + 180) / 360
                    * baseMap.paintedWidth - width / 2
            y: (baseMap.height - baseMap.paintedHeight) / 2
                + (90 - Math.max(-60, Math.min(90, map.latitude))) / 150
                    * baseMap.paintedHeight - height / 2
            width: 14
            height: 14
            radius: width / 2
            color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.28)
            border.color: Ui.Theme.accentText
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: 7
                height: 7
                radius: width / 2
                color: Ui.Theme.accent
            }
        }
    }
}
