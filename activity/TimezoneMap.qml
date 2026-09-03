import QtQuick
import Shelllist.Ui as Ui
import "TimezoneGeometry.js" as Geometry
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: map

    required property date now
    property int offsetSeconds: 0
    property real latitude: 0
    property real longitude: 0
    property bool hasCoordinates: false
    readonly property string selectedLandPath: Geometry.landPathForOffset(offsetSeconds,
        now.getTime())
    readonly property var selectedOceanBand: Geometry.oceanBandForOffset(offsetSeconds)
    readonly property bool hasSelectedRegions: selectedLandPath.length > 0
        || selectedOceanBand.width > 0

    function selectedOffsetSource(): string {
        if (!hasSelectedRegions)
            return "";
        const accent = String(Ui.Theme.accent);
        const outline = String(Ui.Theme.text);
        let regions = "";
        if (selectedOceanBand.width > 0) {
            regions += "<defs><mask id='ocean'><rect width='720' height='360' fill='white'/>"
                + "<path d='" + Geometry.landMaskPath() + "' fill='black'/></mask></defs>"
                + "<rect x='" + selectedOceanBand.x + "' width='" + selectedOceanBand.width
                + "' height='360' fill='" + accent + "' fill-opacity='.48' stroke='" + outline
                + "' stroke-width='1.4' vector-effect='non-scaling-stroke' mask='url(#ocean)'/>";
        }
        if (selectedLandPath.length > 0) {
            regions += "<path d='" + selectedLandPath + "' fill='" + accent
                + "' fill-opacity='.48' stroke='" + outline
                + "' stroke-width='1.8' vector-effect='non-scaling-stroke'/>";
        }
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 720 360'>"
            + regions + "</svg>";
        return "data:image/svg+xml," + encodeURIComponent(svg);
    }

    radius: Ui.Theme.controlRadius
    color: Ui.Theme.surfaceRaised
    border.color: Ui.Theme.border
    clip: true
    Accessible.role: Accessible.Graphic
    Accessible.name: "World map of geographic timezone areas. All regions at "
        + Visuals.utcOffset(offsetSeconds) + " are highlighted, local time "
        + Visuals.localTime(now.getTime(), offsetSeconds)
        + (hasCoordinates ? ". Location marked on the map" : "")

    Item {
        id: mapViewport
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6

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
            source: map.selectedOffsetSource()
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignHCenter
            verticalAlignment: Image.AlignVCenter
            smooth: true
            mipmap: true
            asynchronous: false
            visible: map.hasSelectedRegions
            Accessible.ignored: true
        }

        Rectangle {
            id: locationMarker
            visible: map.hasCoordinates && baseMap.status === Image.Ready
            x: (baseMap.width - baseMap.paintedWidth) / 2
                + (Math.max(-180, Math.min(180, map.longitude)) + 180) / 360
                    * baseMap.paintedWidth - width / 2
            y: (baseMap.height - baseMap.paintedHeight) / 2
                + (85 - Math.max(-60, Math.min(85, map.latitude))) / 145
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
