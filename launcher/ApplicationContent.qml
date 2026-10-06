pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property ApplicationController controller
    chooserController: controller
    refreshEnabled: !content.controller.operationBlocked && navigationEnabled
    detailsTabEnabled: content.controller.detailsOpen && content.controller.hasSelection && refreshEnabled

    property bool restoreWindowCommandFocus: false
    property string commandTarget: ""

    Connections {
        target: content.controller
        function onResultsAboutToChange(): void {
            let item = content.Window.window ? content.Window.window.activeFocusItem : null;
            content.restoreWindowCommandFocus = false;
            while (item && item !== content) {
                if (item.objectName.startsWith("focusWindow-") || item.objectName.startsWith("closeWindow-") || item.objectName.startsWith("windowCommands-"))
                    content.restoreWindowCommandFocus = true;
                item = item.parent;
            }
            content.commandTarget = content.controller.selectedResult ? content.controller.selectedResult.id : "";
        }
        function onResultsChanged(): void {
            if (content.restoreWindowCommandFocus && content.controller.uiActive && !content.controller.uiSuspending
                    && content.controller.detailsOpen && content.controller.selectedResult
                    && content.controller.selectedResult.id === content.commandTarget)
                content.detailsNavigation.focusContent(true);
            content.restoreWindowCommandFocus = false;
        }
    }

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

    Shortcut {
        sequence: "Shift+Return"
        enabled: content.controller.uiActive && content.controller.hasSelection && !content.controller.operationBlocked && content.navigationEnabled && (content.controller.selectedApplication || ({})).kind === "desktop-application"
        onActivated: content.controller.launchSelected()
    }
}
