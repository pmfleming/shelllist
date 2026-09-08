pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ProviderChooserSurface {
    id: content

    required property TimeWeatherController controller
    readonly property alias now: liveClock.now

    chooserController: controller
    surfaceName: "Time & Weather"
    navigationEnabled: !controller.navigationHelpOpen && !controller.screenshotInFlight
    refreshEnabled: !controller.activity.syncing && !controller.screenshotInFlight
    helpEnabled: controller.uiActive
    helpEntries: [
        {
            keys: "Right",
            action: "Expand the selected city"
        },
        {
            keys: "Left",
            action: "Return to the city list"
        },
        {
            keys: "Ctrl+Tab",
            action: "Switch Time and Weather"
        },
        {
            keys: "F5",
            action: "Refresh time and weather"
        }
    ]
    onRefreshRequested: controller.refresh()
    onDetailsTabRequested: controller.cycleDetailsTab()

    listComponent: Component {
        TimeWeatherListPane {
            controller: content.controller
        }
    }
    detailsComponent: Component {
        TimeWeatherDetails {
            controller: content.controller
            now: content.now
            uiScale: content.uiScale
        }
    }

    Ui.LiveClock {
        id: liveClock
        active: content.controller.uiActive
        updateInterval: 30000
    }
}
