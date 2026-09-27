pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "BarMediaPresentation.js" as Presentation

Row {
    id: controls

    required property BarController controller
    property bool multiplePlayers: false
    readonly property bool canSeek: !!controller.activePlayer && !!controller.activePlayer.can_seek
    spacing: 1

    // One visual contract; capability checks and operations remain explicit.
    component Button: Ui.FlatIconButton {
        width: 26
        height: width
        iconSize: 12
        backgroundColor: "transparent"
        radius: 0
        border.width: 0
        flatIconColor: Ui.Theme.mutedText
        highlightedBackgroundColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.18)
        highlightedIconColor: Ui.Theme.accent
        pressedColor: Ui.Theme.withAlpha(Ui.Theme.accent, 0.28)
    }

    Button {
        objectName: "mediaCycleButton"
        icon: "󰑖"
        iconSize: 13
        visible: controls.multiplePlayers
        accessibleName: qsTr("Show next media player")
        onClicked: controls.controller.cycleMediaPlayer()
    }
    Button {
        objectName: "mediaRewindButton"
        icon: ""
        enabled: controls.canSeek
        accessibleName: qsTr("Rewind 15 seconds")
        onClicked: controls.controller.seekMedia(-15)
    }
    Button {
        objectName: "mediaPlayPauseButton"
        width: 28
        icon: Presentation.playPauseActionIcon(controls.controller.activePlayer)
        iconSize: 13
        enabled: !!controls.controller.activePlayer && (!!controls.controller.activePlayer.can_control || !!controls.controller.activePlayer.can_play || !!controls.controller.activePlayer.can_pause)
        accessibleName: qsTr("Play/pause")
        onClicked: controls.controller.mediaOperation("play-pause")
    }
    Button {
        objectName: "mediaForwardButton"
        icon: ""
        enabled: controls.canSeek
        accessibleName: qsTr("Fast-forward 30 seconds")
        onClicked: controls.controller.seekMedia(30)
    }
}
