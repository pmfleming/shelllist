import QtQuick
import Shelllist.Ui as Ui

// Presentation only: artwork follows the inspected player's MPRIS metadata,
// never a service-name lookup or an independently chosen global player.
Ui.DetailCard {
    id: card
    property var player: null
    readonly property bool informationOnly: true
    readonly property bool hasArtwork: artwork.status === Image.Ready

    implicitHeight: Math.max(260, labels.implicitHeight + 4 * Ui.Theme.spacingMd)

    Image {
        id: artwork
        objectName: "mediaPlaybackArtwork"
        anchors.fill: parent
        // Stay inside the card's padding, including its rounded outer corners.
        source: card.visible && card.player ? card.player.art_url || "" : ""
        sourceSize.width: Math.min(1600, Math.ceil(width * Screen.devicePixelRatio))
        sourceSize.height: Math.min(1200, Math.ceil(height * Screen.devicePixelRatio))
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: card.hasArtwork
        Accessible.ignored: true
    }
    Ui.GlyphLabel {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Ui.Theme.spacingMd
        glyph: "music_note"
        font.pixelSize: 96
        color: Ui.Theme.mutedText
        opacity: 0.18
        visible: !card.hasArtwork
        Accessible.ignored: true
    }
    Rectangle {
        anchors.fill: labels
        anchors.margins: -Ui.Theme.spacingMd
        // Even white artwork must leave every line readable in either theme.
        color: card.hasArtwork ? "#cc000000" : "transparent"
    }
    Column {
        id: labels
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Ui.Theme.spacingMd
        spacing: Ui.Theme.spacingSm

        Ui.ThemeText {
            width: parent.width
            text: qsTr("Now playing")
            color: card.hasArtwork ? "white" : Ui.Theme.text
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightMedium
        }
        Ui.ThemeText {
            objectName: "mediaPlaybackTitle"
            width: parent.width
            text: card.player ? card.player.title || qsTr("No track title") : ""
            color: card.hasArtwork ? "white" : Ui.Theme.text
            wrapMode: Text.WordWrap
            font.pixelSize: Ui.Theme.fontSizeHeading
        }
        Ui.ThemeText {
            objectName: "mediaPlaybackSubtitle"
            width: parent.width
            text: card.player ? [card.player.artist, card.player.album].filter(Boolean).join(" · ") : ""
            visible: text.length > 0
            wrapMode: Text.WordWrap
            color: card.hasArtwork ? "#eeeeee" : Ui.Theme.mutedText
        }
    }
}
