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
        }
    ]
    refreshHelp: "Refresh time and weather"
    detailsTabHelp: "Switch Time and Weather"

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
