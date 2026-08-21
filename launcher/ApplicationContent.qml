pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property ApplicationController controller
    readonly property real uiScale: Ui.Theme.densityScale(height, controller.contentVerticalMargin)

    Ui.ChooserShortcuts {
        controller: content.controller
        navigationEnabled: !content.controller.navigationHelpOpen
        refreshEnabled: !content.controller.actionInFlight
            && !content.controller.settingsInFlight
            && !content.controller.navigationHelpOpen
        detailsTabEnabled: content.controller.detailsOpen && content.controller.hasSelection
            && !content.controller.actionInFlight && !content.controller.settingsInFlight
            && !content.controller.navigationHelpOpen
        onRefreshRequested: content.controller.refresh(true)
        onDetailsTabRequested: content.controller.cycleDetailsTab()
    }
    Shortcut {
        sequence: "Shift+Return"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && !content.controller.actionInFlight && !content.controller.settingsInFlight
            && !content.controller.navigationHelpOpen
            && (content.controller.selectedApplication || ({})).kind === "desktop-application"
        onActivated: content.controller.launchSelected()
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

    Ui.NavigationHelpDialog {
        controller: content.controller
        surfaceName: "Applications"
        helpEnabled: content.controller.uiActive
        entries: [
            { keys: "Shift+Enter", action: "Launch a new application instance" },
            { keys: "F5", action: "Refresh applications and windows" },
            { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
        ]
    }
}
