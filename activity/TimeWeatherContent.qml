pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property TimeWeatherController controller
    property date now

    chooserController: controller
    surfaceName: "Time & Weather"
    navigationEnabled: !controller.navigationHelpOpen
    refreshEnabled: !controller.activity.syncing
    detailsTabEnabled: controller.detailsOpen && controller.hasSelection
    helpEnabled: controller.uiActive
    helpEntries: [
        { keys: "Right", action: "Expand the selected city" },
        { keys: "Left", action: "Return to the city list" },
        { keys: "Ctrl+Tab", action: "Switch Time and Weather" },
        { keys: "F5", action: "Refresh time and weather" }
    ]
    onRefreshRequested: controller.refresh()
    onDetailsTabRequested: controller.cycleDetailsTab()

    listComponent: Component {
        TimeWeatherListPane { controller: content.controller }
    }
    detailsComponent: Component {
        TimeWeatherDetails {
            controller: content.controller
            now: content.now
        }
    }

    Component.onCompleted: now = new Date()

    Connections {
        target: content.controller
        function onUiActiveChanged(): void {
            if (content.controller.uiActive)
                content.now = new Date();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: content.controller.uiActive
        onTriggered: content.now = new Date()
    }
}
