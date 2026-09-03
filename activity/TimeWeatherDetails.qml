pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane

    required property TimeWeatherController controller
    required property date now
    readonly property var city: controller.selectedCity
    readonly property int footerHeight: Math.max(36,
        Math.round(Ui.Theme.controlHeight * uiScale))

    chooserController: controller
    emptyText: "Select a city"
    headerHeight: Math.max(58, Math.round(66 * uiScale))
    controlHeight: footerHeight
    icon: city.home ? "󰋜" : "󰍎"
    iconColor: Ui.Theme.accent
    title: city.label || "City"
    subtitle: city.timezone || "Timezone unavailable"

    Ui.TabbedDetailsStack {
        anchors.fill: parent
        footerHeight: pane.footerHeight
        sectionSpacing: pane.sectionSpacing
        selectedValue: pane.controller.detailsTab
        tabs: [
            { value: "time", icon: "󰥔", label: "Time" },
            { value: "weather", icon: "󰖐", label: "Weather" }
        ]
        onSelected: function (value) { pane.controller.setDetailsTab(value); }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "time"
            asynchronous: true
            sourceComponent: Component {
                TimeWeatherTimePane {
                    city: pane.city
                    now: pane.now
                }
            }
        }

        Loader {
            anchors.fill: parent
            active: pane.controller.detailsTab === "weather"
            asynchronous: true
            sourceComponent: pane.city.has_weather
                ? weatherComponent : noWeatherComponent
        }
    }

    Component {
        id: weatherComponent
        ActivityWeatherPane {
            controller: pane.controller
            now: pane.now
            showLocationRail: false
        }
    }

    Component {
        id: noWeatherComponent
        Ui.CenteredMessage {
            text: "Weather is not configured for "
                + String(pane.city.label || "this city")
        }
    }
}
