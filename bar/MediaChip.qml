import QtQuick
import QtQuick.Controls as Controls
import Shelllist.Ui as Ui
import "BarPresentation.js" as Presentation

Item {
    id: root

    required property BarController controller
    required property int layoutDensity
    property double nowMs: Date.now()
    readonly property var player: controller.activePlayer
    readonly property string title: player
        ? (player.title || player.identity || "Unknown track") : ""
    readonly property string labelText: player && player.artist && layoutDensity === 0
        ? title + " — " + player.artist : title
    readonly property real progress: Presentation.mediaPositionPercent(player, nowMs)

    implicitWidth: Math.min(420, artFrame.width + titleLabel.implicitWidth
        + mediaControls.implicitWidth + 34)
    implicitHeight: 37

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Ui.Theme.withAlpha(Ui.Theme.mix(Ui.Theme.surfaceRaised,
            Ui.Theme.accent, 0.08), 0.72)
        border.width: 1
        border.color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.42)
    }

    Rectangle {
        id: artFrame

        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        width: 27
        height: 27
        radius: width / 2
        color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.18)
        clip: true

        Image {
            id: artwork

            anchors.fill: parent
            source: root.player ? root.player.art_url || "" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            opacity: status === Image.Ready ? 1 : 0

            Behavior on opacity {
                enabled: !Ui.Theme.noAnimations
                NumberAnimation { duration: Ui.Theme.animationNormal }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: artwork.status !== Image.Ready
            text: Presentation.playerIcon(root.player)
            color: Ui.Theme.accent
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: Ui.Theme.iconSizeSmall
        }
    }

    Text {
        id: titleLabel

        anchors.left: artFrame.right
        anchors.leftMargin: 8
        anchors.right: mediaControls.left
        anchors.rightMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        text: root.labelText
        color: Ui.Theme.text
        elide: Text.ElideRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Ui.Theme.fontSizeSmall
        font.weight: Ui.Theme.fontWeightDemiBold
        onTextChanged: if (!Ui.Theme.noAnimations) titlePulse.restart()
    }

    Row {
        id: mediaControls

        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1

        Ui.FlatIconButton {
            width: 26
            height: 26
            icon: ""
            iconSize: 12
            flatIconColor: Ui.Theme.mutedText
            highlightedBackgroundColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.18)
            highlightedIconColor: Ui.Theme.accent
            toolTip: "Previous track"
            enabled: !!root.player && !!root.player.can_previous
            onClicked: root.controller.mediaOperation("previous")
        }

        Ui.FlatIconButton {
            width: 28
            height: 28
            icon: Presentation.playPauseActionIcon(root.player)
            iconSize: 13
            flatIconColor: Ui.Theme.accent
            highlightedBackgroundColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.22)
            highlightedIconColor: Ui.Theme.accent
            toolTip: root.player
                && String(root.player.playback_status || "").toLowerCase() === "playing"
                ? "Pause" : "Play"
            enabled: !!root.player && (!!root.player.can_control
                || !!root.player.can_play || !!root.player.can_pause)
            onClicked: root.controller.mediaOperation("play-pause")
        }

        Ui.FlatIconButton {
            width: 26
            height: 26
            icon: ""
            iconSize: 12
            flatIconColor: Ui.Theme.mutedText
            highlightedBackgroundColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.18)
            highlightedIconColor: Ui.Theme.accent
            toolTip: "Next track"
            enabled: !!root.player && !!root.player.can_next
            onClicked: root.controller.mediaOperation("next")
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 2
        anchors.rightMargin: 2
        anchors.bottom: parent.bottom
        height: root.player && Number(root.player.length_us || 0) > 0 ? 3 : 0
        radius: height / 2
        color: Ui.Theme.withAlpha(Ui.Theme.accent, 0.14)
        clip: true

        Rectangle {
            width: parent.width * root.progress / 100
            height: parent.height
            radius: parent.radius
            color: Ui.Theme.accent

            Behavior on width {
                enabled: !Ui.Theme.noAnimations
                NumberAnimation {
                    duration: 500
                    easing.type: Easing.Linear
                }
            }
        }
    }

    SequentialAnimation {
        id: titlePulse

        NumberAnimation {
            target: titleLabel
            property: "opacity"
            to: 0.32
            duration: Math.round(Ui.Theme.animationFast * 0.35)
        }
        NumberAnimation {
            target: titleLabel
            property: "opacity"
            to: 1
            duration: Math.round(Ui.Theme.animationFast * 0.65)
        }
    }

    Ui.StateLayer {
        id: pointer

        anchors.right: mediaControls.left
        anchors.rightMargin: 2
        focusTarget: root
        radius: height / 2
        stateColor: Ui.Theme.accent
        showStateBackground: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.controller.mediaOperation("play-pause")
    }

    Controls.ToolTip.visible: pointer.hovered
    Controls.ToolTip.text: root.player
        ? [root.player.artist || root.player.identity || "", root.player.album || ""]
            .filter(Boolean).join("\n") : ""
    Controls.ToolTip.delay: 500

    Timer {
        interval: 500
        repeat: true
        running: root.visible && root.player
            && String(root.player.playback_status || "").toLowerCase() === "playing"
        onTriggered: root.nowMs = Date.now()
    }
}
