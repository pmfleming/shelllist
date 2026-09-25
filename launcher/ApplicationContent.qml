pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property ApplicationController controller
    chooserController: controller
    surfaceName: "Applications"
    refreshEnabled: !content.controller.operationBlocked && navigationEnabled
    detailsTabEnabled: content.controller.detailsOpen && content.controller.hasSelection && refreshEnabled
    refreshHelp: "Refresh applications and windows"

    function refresh(): void {
        content.controller.refresh(true);
    }

    listComponent: Component {
        ApplicationListPane {
            controller: content.controller
        }
    }
    detailsComponent: Component {
        ApplicationDetails {
            controller: content.controller
            uiScale: content.uiScale
        }
    }

    Ui.SurfaceShortcut {
        sequence: "Shift+Return"
        help: "Launch a new application instance"
        enabled: content.controller.uiActive && content.controller.hasSelection && !content.controller.operationBlocked && content.navigationEnabled && (content.controller.selectedApplication || ({})).kind === "desktop-application"
        onActivated: content.controller.launchSelected()
    }
}
