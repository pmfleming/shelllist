pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Shelllist.Ui as Ui

Item {
    id: root
    required property BarController controller
    readonly property var player: controller.activePlayer
    implicitWidth: artworkButton.width + mediaControls.implicitWidth + 12
    implicitHeight: 38

    // A passive group, not a fifth action. Leave enough height for the existing
    // 36px play/pause target inside the bar's 39px content area.
    Rectangle {
        objectName: "mediaGroupBackground"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.implicitHeight
        radius: height / 2
        color: Ui.Theme.surfaceContainer
    }
    Ui.FlatIconButton {
        id: artworkButton
        objectName: "mediaArtworkButton"
        anchors.left: parent.left
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        height: 34
        iconSize: 20
        activeFocusOnTab: false
        browseIndicatorVisible: false
        icon: artwork.status === Image.Ready ? "" : "󰎆"
        accessibleName: qsTr("Open Media") + (root.player ? ". " + (root.player.title || root.player.identity || "") : "")
        backgroundColor: "transparent"
        flatIconColor: Ui.Theme.text
        highlightedBackgroundColor: Ui.Theme.hover
        highlightedIconColor: Ui.Theme.text
        pressedColor: Ui.Theme.pressed
        border.width: 0
        onClicked: root.controller.openSurface("media")
        Rectangle {
            id: artworkMask
            width: 30
            height: 30
            radius: width / 2
            color: "white"
            visible: false
            layer.enabled: true
        }
        Rectangle {
            objectName: "mediaArtworkBackdrop"
            anchors.centerIn: parent
            width: artworkMask.width
            height: artworkMask.height
            radius: artworkMask.radius
            color: Ui.Theme.window
            visible: artwork.status === Image.Ready
            // Rectangle.clip only clips a square. Mask both the image and its
            // opaque backing so bright covers really have rounded corners.
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: artworkMask
            }
            Image {
                id: artwork
                objectName: "mediaArtwork"
                anchors.fill: parent
                source: root.player ? root.player.art_url || "" : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
            }
        }
    }
    MediaControls {
        id: mediaControls
        objectName: "mediaTransportControls"
        controller: root.controller
        anchors.left: artworkButton.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
    }
}
