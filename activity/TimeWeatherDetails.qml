pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "WeatherVisuals.js" as Visuals

Ui.ActionDetailsPane {
    id: pane
    objectName: "timeWeatherDetails"

    required property TimeWeatherController controller
    required property date now
    readonly property var city: controller.selectedCity

    chooserController: controller
    emptyText: "Select a city"
    icon: city.home ? "󰋜" : "󰍎"
    iconColor: Ui.Theme.accent
    title: city.label || "City"
    subtitle: Visuals.locationSubtitle(city)

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.controlHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: [
            {
                value: "time",
                icon: "󰥔",
                label: "Time"
            },
            {
                value: "weather",
                icon: "󰖐",
                label: "Weather"
            }
        ]
        onSelected: function (value) {
            pane.controller.setDetailsTab(value);
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "time"
            asynchronous: true
            sourceComponent: Component {
                TimeWeatherTimePane {
                    viewMemory: pane.controller.viewMemory
                    memoryTab: "time"
                    city: pane.city
                    now: pane.now
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "weather"
            asynchronous: true
            sourceComponent: pane.city.has_weather ? weatherComponent : noWeatherComponent
        }
    }

    Component {
        id: weatherComponent
        ActivityWeatherPane {
            viewMemory: pane.controller.viewMemory
            memoryTab: "weather"
            controller: pane.controller
            now: pane.now
            showLocationRail: false
        }
    }

    Component {
        id: noWeatherComponent
        Ui.CenteredMessage {
            // The Loader supplies the message's bounds; no parent anchors.
            text: "Weather is not configured for " + String(pane.city.label || "this city")
        }
    }
}
