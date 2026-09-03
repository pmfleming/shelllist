pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Item {
    id: details

    required property TimeWeatherController controller
    required property date now
    readonly property var city: controller.selectedCity
    readonly property real uiScale: Ui.Theme.densityScale(height,
        controller.contentVerticalMargin)

    Column {
        anchors.fill: parent
        spacing: Ui.Theme.spacingMd

        Ui.DetailsHeader {
            width: parent.width
            uiScale: details.uiScale
            icon: details.controller.detailsTab === "time" ? "󰥔" : "󰖐"
            iconColor: Ui.Theme.accent
            title: details.city.label || "City"
            subtitle: details.city.timezone || "Timezone unavailable"
        }

        Ui.SegmentedControl {
            width: parent.width
            height: Ui.Theme.compactControlHeight
            options: [
                { value: "time", label: "Time" },
                { value: "weather", label: "Weather" }
            ]
            value: details.controller.detailsTab
            onSelected: function (value) { details.controller.setDetailsTab(value); }
        }

        Loader {
            width: parent.width
            height: parent.height - y
            active: details.controller.detailsOpen
            sourceComponent: details.controller.detailsTab === "time"
                ? timeComponent : details.city.has_weather
                    ? weatherComponent : noWeatherComponent
        }
    }

    Component {
        id: timeComponent
        TimeWeatherTimePane {
            city: details.city
            now: details.now
        }
    }

    Component {
        id: weatherComponent
        ActivityWeatherPane {
            controller: details.controller
            now: details.now
            showLocationRail: false
        }
    }

    Component {
        id: noWeatherComponent
        Ui.CenteredMessage {
            text: "Weather is not configured for "
                + String(details.city.label || "this city")
        }
    }
}
