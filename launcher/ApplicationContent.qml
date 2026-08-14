pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ApplicationController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (content.controller.detailsOpen)
                content.controller.closeDetails();
            else
                content.controller.closeWindowRequested();
        }
    }
    Shortcut {
        sequence: "F5"
        enabled: !content.controller.actionInFlight
        onActivated: content.controller.refresh(true)
    }
    Shortcut {
        sequence: "Shift+Return"
        enabled: content.controller.hasSelection && !content.controller.actionInFlight
            && (content.controller.selectedApplication || ({})).kind === "desktop-application"
        onActivated: content.controller.launchSelected()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.detailsOpen && content.controller.hasSelection
            && !content.controller.actionInFlight
        onActivated: content.controller.cycleDetailsTab()
    }

    Ui.SplitChooserLayout {
        controller: content.controller
        listComponent: Component {
            ApplicationListPane { controller: content.controller; uiScale: content.uiScale }
        }
        detailsComponent: Component {
            ApplicationDetails { controller: content.controller; uiScale: content.uiScale }
        }
    }
}
