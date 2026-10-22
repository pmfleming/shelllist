pragma ComponentBehavior: Bound

import QtQuick

// Passive playback state, not an audio-level meter. The owner supplies the
// acknowledged glyph and gates motion to its active, visible viewport.
Item {
    id: indicator

    property string glyph: "stop"
    property bool active: false
    property color color: glyph === "equalizer" ? Theme.active : Theme.mutedText
    readonly property bool animating: active && visible && glyph === "equalizer" && !Theme.noAnimations

    implicitWidth: Theme.iconSize
    implicitHeight: Theme.iconSize
    Accessible.ignored: true

    GlyphLabel {
        anchors.fill: parent
        visible: indicator.glyph !== "equalizer"
        glyph: indicator.glyph
        color: indicator.color
        font.pixelSize: Math.min(indicator.width, indicator.height)
        Accessible.ignored: true
    }

    Repeater {
        model: 3
        delegate: Rectangle {
            id: bar
            required property int index
            objectName: "playbackBar" + index
            readonly property real restLevel: [0.4, 0.75, 0.55][index]
            property real level: restLevel
            visible: indicator.glyph === "equalizer"
            // Shared UI owns these proportional glyph strokes. Keep the icon's
            // footprint and baseline fixed while only its three bars move.
            x: indicator.width * (0.175 + index * 0.25)
            y: indicator.height * 0.875 - height
            width: indicator.width * 0.15
            height: indicator.height * (indicator.animating ? level : restLevel)
            radius: width / 2
            color: indicator.color
            Accessible.ignored: true

            SequentialAnimation on level {
                objectName: "playbackBarAnimation"
                running: indicator.animating
                loops: Animation.Infinite
                NumberAnimation {
                    from: bar.restLevel
                    to: [0.75, 0.85, 0.65][bar.index]
                    duration: 320 + bar.index * 70
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: [0.2, 0.25, 0.3][bar.index]
                    duration: 280 + bar.index * 60
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: bar.restLevel
                    duration: 240 + bar.index * 50
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
