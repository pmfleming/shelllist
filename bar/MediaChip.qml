import QtQuick
import Shelllist.Ui as Ui

Item {
    id: root
    required property BarController controller
    required property int layoutDensity
    readonly property var player: controller.activePlayer
    readonly property bool compact: layoutDensity >= 3
    implicitWidth: artworkButton.width + (mediaControls.visible ? mediaControls.implicitWidth + 4 : 0)
    implicitHeight: 37

    Ui.FlatIconButton {
        id: artworkButton
        objectName: "mediaArtworkButton"
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        activeFocusOnTab: false
        icon: artwork.status === Image.Ready ? "" : "󰎆"
        accessibleName: qsTr("Open Media") + (root.player ? ". " + (root.player.title || root.player.identity || "") : "")
        backgroundColor: "transparent"
        border.width: 0
        onClicked: root.controller.openSurface("media")
        Image {
            id: artwork
            anchors.fill: parent
            anchors.margins: 4
            source: root.player ? root.player.art_url || "" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: status === Image.Ready
        }
    }
    MediaControls {
        id: mediaControls
        visible: !!root.player && !root.compact
        controller: root.controller
        anchors.left: artworkButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
}
