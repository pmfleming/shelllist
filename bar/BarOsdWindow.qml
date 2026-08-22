import Quickshell
import Quickshell.Wayland
import QtQuick

BarOverlayWindow {
    id: window
    // Keep the focused monitor's layer surface mapped so a media-key press does
    // not pay a Wayland surface creation/configure round trip before appearing.
    implicitWidth: 376
    implicitHeight: 104
    mask: Region {}
    WlrLayershell.namespace: "shelllist-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors {
        bottom: true
        left: true
    }
    margins { // qmllint disable unresolved-type unqualified
        bottom: 86
        left: Math.max(0, Math.round(((window.screen ? window.screen.width : 376)
            - window.implicitWidth) / 2))
    }

    BarOsdContent {
        anchors.fill: parent
        controller: window.controller
    }
}
