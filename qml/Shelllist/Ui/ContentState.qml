pragma ComponentBehavior: Bound

import QtQuick

// Passive missing-content presentation. The owner supplies authoritative read
// state; this item never owns requests, commands, selection or focus.
Item {
    id: message

    property string icon: ""
    property string text: ""
    // empty, loading, filtered, unavailable, disabled, collecting
    property string kind: "empty"
    property bool compact: false
    property bool showLabel: true
    property bool active: true
    property real uiScale: 1
    readonly property real iconSize: (compact ? 36 : 64) * uiScale
    readonly property string badgeIcon: kind === "loading" ? "refresh" : kind === "filtered" ? "search" : kind === "unavailable" ? "error" : ""
    readonly property bool spinning: visible && active && kind === "loading" && !Theme.noAnimations

    implicitHeight: content.implicitHeight + 2 * Theme.spacingMd
    clip: true
    Accessible.role: Accessible.StaticText
    Accessible.name: text

    Column {
        id: content
        anchors.centerIn: parent
        width: Math.max(0, parent.width - 2 * Theme.spacingMd)
        spacing: Theme.spacingMd

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: message.iconSize
            height: width
            visible: message.icon.length > 0

            GlyphLabel {
                objectName: "contentStateGlyph"
                anchors.fill: parent
                glyph: message.icon
                font.pixelSize: message.iconSize
                Accessible.ignored: true
            }
            Rectangle {
                visible: message.badgeIcon.length > 0
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: -6 * message.uiScale
                anchors.bottomMargin: -4 * message.uiScale
                width: 26 * message.uiScale
                height: width
                radius: width / 2
                color: Theme.surface
                GlyphLabel {
                    id: badge
                    objectName: "contentStateBadge"
                    anchors.centerIn: parent
                    glyph: message.badgeIcon
                    font.pixelSize: 18 * message.uiScale
                    color: message.kind === "unavailable" ? Theme.danger : Theme.mutedText
                    Accessible.ignored: true
                    RotationAnimation on rotation {
                        from: 0
                        to: 360
                        duration: Theme.spinnerDuration
                        loops: Animation.Infinite
                        running: message.spinning
                    }
                    Connections {
                        target: message
                        function onSpinningChanged(): void {
                            if (!message.spinning)
                                badge.rotation = 0;
                        }
                    }
                }
            }
        }
        ThemeText {
            objectName: "contentStateLabel"
            width: parent.width
            visible: message.showLabel || !message.icon || message.kind === "unavailable" || message.kind === "disabled"
            text: message.text
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: message.compact ? Theme.fontSizeCaption : Theme.fontSizeBody
            color: message.kind === "unavailable" ? Theme.danger : Theme.mutedText
            Accessible.ignored: true
        }
    }
}
