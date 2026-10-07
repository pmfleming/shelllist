import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Shelllist.Ui as Ui
import "BarMediaPresentation.js" as Media

// The inspected session owns all artwork/timing. This entire card is passive:
// no seek slider, field focus, pinning or implicit transport operation.
Ui.DetailCard {
    id: card
    property var player: null
    property bool active: true
    property double nowMs: Date.now()
    readonly property bool informationOnly: true
    readonly property bool hasArtwork: artwork.status === Image.Ready
    readonly property bool playing: !!player && String(player.playback_status).toLowerCase() === "playing"
    readonly property var timing: Media.timeline(player, nowMs)
    readonly property string kind: Media.contentKind(player)
    readonly property string timingScope: kind === "music" ? qsTr("track") : kind === "podcast" ? qsTr("episode") : qsTr("reported segment")
    readonly property real coverSize: Math.min(156, Math.max(96, width * 0.28))
    implicitHeight: body.implicitHeight + 2 * verticalContentPadding
    contentPadding: Ui.Theme.spacingLg
    verticalContentPadding: Ui.Theme.spacingLg
    radius: Ui.Theme.panelRadius
    color: Ui.Theme.selected
    onPlayerChanged: nowMs = Date.now()
    onVisibleChanged: if (visible) nowMs = Date.now()
    onActiveChanged: if (active) nowMs = Date.now()

    Timer {
        interval: 1000
        repeat: true
        running: card.visible && card.active && card.playing && card.timing.known
        onTriggered: card.nowMs = Date.now()
    }
    Column {
        id: body
        width: parent.width
        spacing: Ui.Theme.spacingXl
        RowLayout {
            width: parent.width
            spacing: Ui.Theme.spacingLg
            Rectangle {
                Layout.preferredWidth: card.coverSize
                Layout.preferredHeight: card.coverSize
                Layout.alignment: Qt.AlignVCenter
                radius: Ui.Theme.formRadius
                color: Ui.Theme.surfaceContainer
                Image {
                    id: artwork
                    objectName: "mediaPlaybackArtwork"
                    anchors.fill: parent
                    anchors.margins: Ui.Theme.spacingXs
                    source: card.visible && card.player ? card.player.art_url || "" : ""
                    sourceSize: Qt.size(Math.ceil(card.coverSize * Screen.devicePixelRatio), Math.ceil(card.coverSize * Screen.devicePixelRatio))
                    asynchronous: true
                    fillMode: Image.PreserveAspectFit
                    visible: card.hasArtwork
                    Accessible.ignored: true
                }
                Ui.GlyphLabel {
                    anchors.centerIn: parent
                    visible: !card.hasArtwork
                    glyph: Media.contentIcon(card.player)
                    font.pixelSize: card.coverSize * 0.45
                    color: Ui.Theme.mutedText
                    Accessible.ignored: true
                }
            }
            Column {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: Ui.Theme.spacingSm
                Ui.GlyphLabel {
                    glyph: Media.contentIcon(card.player)
                    font.pixelSize: Ui.Theme.iconSize
                    color: Ui.Theme.selectedText
                    Accessible.role: Accessible.StaticText
                    Accessible.name: card.kind === "podcast" ? qsTr("Podcast") : card.kind === "audiobook" ? qsTr("Audiobook") : card.kind === "music" ? qsTr("Music") : card.kind === "video" ? qsTr("Video") : qsTr("Media")
                }
                Ui.ThemeText {
                    objectName: "mediaPlaybackTitle"
                    width: parent.width
                    text: card.player ? card.player.title || Media.heading(card.player) : ""
                    textFormat: Text.PlainText
                    color: Ui.Theme.selectedText
                    wrapMode: Text.WordWrap
                    font.pixelSize: Ui.Theme.fontSizeDisplay
                    font.weight: Ui.Theme.fontWeightMedium
                }
                Ui.ThemeText {
                    objectName: "mediaPlaybackSubtitle"
                    width: parent.width
                    text: Media.subtitle(card.player)
                    textFormat: Text.PlainText
                    visible: text.length > 0
                    wrapMode: Text.WordWrap
                    color: Ui.Theme.selectedText
                }
            }
        }
        Column {
            width: parent.width
            spacing: Ui.Theme.spacingSm
            Item {
                id: progress
                objectName: "mediaPlaybackProgress"
                width: parent.width
                height: 24
                visible: card.timing.known
                readonly property real position: Math.max(0, (width - 4) * card.timing.fraction)
                readonly property real filledWidth: Math.max(0, position - 5)
                Accessible.ignored: true
                Rectangle {
                    x: progress.position + 9
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(0, parent.width - x)
                    height: 6
                    radius: 3
                    color: Ui.Theme.materialPalette.outlineVariant
                }
                Rectangle {
                    width: progress.filledWidth
                    anchors.verticalCenter: parent.verticalCenter
                    height: 6
                    radius: 3
                    color: Ui.Theme.accent
                    visible: !wave.visible
                }
                Shape {
                    id: wave
                    visible: card.playing && !Ui.Theme.noAnimations && progress.filledWidth > 0
                    width: progress.filledWidth
                    height: parent.height
                    // Static expressive wave, not an invented audio waveform.
                    function wavePath(): string {
                        let path = "M 0 12";
                        for (let x = 0; x < width; x += 12) {
                            const end = Math.min(x + 12, width);
                            path += " Q " + (x + (end - x) / 2) + " " + (Math.floor(x / 12) % 2 ? 20 : 4) + " " + end + " 12";
                        }
                        return path;
                    }
                    ShapePath {
                        strokeColor: Ui.Theme.accent
                        strokeWidth: 3
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathSvg { path: wave.wavePath() }
                    }
                }
                Rectangle {
                    x: progress.position
                    width: 4
                    height: parent.height
                    radius: 2
                    color: Ui.Theme.accent
                }
            }
            RowLayout {
                width: parent.width
                Ui.ThemeText {
                    objectName: "mediaElapsed"
                    Layout.fillWidth: true
                    text: card.timing.elapsed
                    color: Ui.Theme.selectedText
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    Accessible.name: card.timing.known ? qsTr("%1 elapsed in this %2").arg(text).arg(card.timingScope) : qsTr("Position not reported")
                }
                Ui.ThemeText {
                    objectName: "mediaPlaybackRate"
                    text: card.timing.speed
                    visible: text.length > 0
                    color: Ui.Theme.selectedText
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    Accessible.name: qsTr("Playback speed: %1").arg(text)
                }
                Ui.ThemeText {
                    objectName: "mediaRemaining"
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: card.timing.remaining
                    color: Ui.Theme.selectedText
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    Accessible.name: card.timing.known ? qsTr("%1 remaining in this %2").arg(text.slice(1)).arg(card.timingScope) : qsTr("Duration not reported")
                }
            }
        }
    }
}
