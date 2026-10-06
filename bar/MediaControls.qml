import QtQuick
import Shelllist.Ui as Ui
import "BarMediaPresentation.js" as Presentation

Row {
    id: controls
    required property BarController controller
    readonly property var back: Presentation.transportAction(controller.activePlayer, false)
    readonly property var forward: Presentation.transportAction(controller.activePlayer, true)
    spacing: 2

    function perform(action: var): void {
        if (!action.enabled)
            return;
        if (action.operation === "seek")
            controller.seekMedia(action.offset);
        else
            controller.mediaOperation(action.operation);
    }
    component Button: Ui.FlatIconButton {
        width: 30
        height: 30
        iconSize: 20
        anchors.verticalCenter: parent.verticalCenter
        activeFocusOnTab: false
        backgroundColor: "transparent"
        border.width: 0
        flatIconColor: Ui.Theme.text
        highlightedBackgroundColor: Ui.Theme.hover
        highlightedIconColor: Ui.Theme.text
        pressedColor: Ui.Theme.pressed
    }
    Button {
        objectName: "mediaRewindButton"
        icon: controls.back.icon
        enabled: controls.back.enabled
        accessibleName: controls.back.label
        onClicked: controls.perform(controls.back)
    }
    Button {
        objectName: "mediaPlayPauseButton"
        width: 36
        height: 36
        iconSize: 24
        backgroundColor: Ui.Theme.accent
        flatIconColor: Ui.Theme.accentText
        highlightedBackgroundColor: Ui.Theme.accent
        highlightedIconColor: Ui.Theme.accentText
        icon: Presentation.playPauseActionIcon(controls.controller.activePlayer)
        enabled: Presentation.canPlayPause(controls.controller.activePlayer)
        accessibleName: qsTr("Play/pause")
        onClicked: controls.controller.mediaOperation("play-pause")
    }
    Button {
        objectName: "mediaForwardButton"
        icon: controls.forward.icon
        enabled: controls.forward.enabled
        accessibleName: controls.forward.label
        onClicked: controls.perform(controls.forward)
    }
}
