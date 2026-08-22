pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property ApplicationController controller
    chooserController: controller
    surfaceName: "Applications"
    navigationEnabled: !content.controller.navigationHelpOpen
    refreshEnabled: !content.controller.operationBlocked && navigationEnabled
    detailsTabEnabled: content.controller.detailsOpen && content.controller.hasSelection
        && refreshEnabled
    helpEnabled: content.controller.uiActive
    helpEntries: [
        { keys: "Shift+Enter", action: "Launch a new application instance" },
        { keys: "F5", action: "Refresh applications and windows" },
        { keys: "Ctrl+Tab", action: "Cycle detail tabs" }
    ]
    onRefreshRequested: content.controller.refresh(true)
    onDetailsTabRequested: content.controller.cycleDetailsTab()

    listComponent: Component {
        ApplicationListPane { controller: content.controller }
    }
    detailsComponent: Component {
        ApplicationDetails { controller: content.controller; uiScale: content.uiScale }
    }

    Shortcut {
        sequence: "Shift+Return"
        enabled: content.controller.uiActive && content.controller.hasSelection
            && !content.controller.operationBlocked && content.navigationEnabled
            && (content.controller.selectedApplication || ({})).kind === "desktop-application"
        onActivated: content.controller.launchSelected()
    }
}
