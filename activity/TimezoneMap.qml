pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Rectangle {
    id: map

    required property date now
    property int offsetSeconds: 0
    property real latitude: 0
    property real longitude: 0
    property bool hasCoordinates: false
    property var regionIds: []
    readonly property bool hasOceanBand: offsetSeconds % 3600 === 0
        && offsetSeconds >= -12 * 3600 && offsetSeconds <= 12 * 3600
    readonly property real oceanBandCenter: (offsetSeconds / 3600 * 15 + 180) * 2
    readonly property real oceanBandLeft: Math.max(0, oceanBandCenter - 15)
    readonly property real oceanBandWidth: hasOceanBand
        ? Math.min(720, oceanBandCenter + 15) - oceanBandLeft : 0

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

        Rectangle {
            visible: map.hasOceanBand && baseMap.status === Image.Ready
            x: (baseMap.width - baseMap.paintedWidth) / 2
                + map.oceanBandLeft / 720 * baseMap.paintedWidth
            y: (baseMap.height - baseMap.paintedHeight) / 2
            width: map.oceanBandWidth / 720 * baseMap.paintedWidth
            height: baseMap.paintedHeight
            color: Ui.Theme.accent
            border.color: Ui.Theme.text
            border.width: 1
        }

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

        Repeater {
            model: map.regionIds

            delegate: Image {
                required property string modelData
                anchors.fill: mapViewport
                source: Qt.resolvedUrl("assets/timezones/regions/" + modelData + ".svg")
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignHCenter
                verticalAlignment: Image.AlignVCenter
                smooth: true
                mipmap: true
                asynchronous: true
                Accessible.ignored: true
            }
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
