pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Rectangle {
    id: content

    required property ClipboardController controller
    required property ClipboardWindowHost windowHost
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    anchors.fill: parent
    radius: Ui.Theme.windowRadius
    color: Ui.Theme.window
    border.color: Ui.Theme.strongBorder
    border.width: 1

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (content.controller.detailsOpen)
                content.controller.closeDetails();
            else
                content.windowHost.closeRequested();
        }
    }
    Shortcut { sequence: "F5"; onActivated: content.controller.refresh() }

    Ui.SplitChooserLayout {
        id: chooser
        controller: content.controller
        listComponent: Component {
            ClipboardListPane { controller: content.controller; uiScale: content.uiScale }
        }
        detailsComponent: Component {
            ClipboardDetails { controller: content.controller; uiScale: content.uiScale }
        }
    }

    Connections {
        target: content.controller
        function onFocusSearchRequested() { Qt.callLater(chooser.listItem.focusSearch); }
        function onFocusListTopRequested() { Qt.callLater(chooser.listItem.focusTop); }
    }
}
