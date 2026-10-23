pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: pane

    required property ActivityController controller
    property bool showLocationRail: true
    readonly property var weather: controller.selectedWeather

    WeatherLocationRail {
        visible: pane.showLocationRail
        height: visible ? 108 : 0
        locations: pane.controller.weatherLocations
        selectedId: pane.weather.id || ""
        onSelected: function (locationId) {
            pane.controller.selectWeatherLocation(locationId);
        }
    }

    WeatherHero {
        weather: pane.weather
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
    }

    Ui.FeedbackSource {
        active: Number(pane.weather.updated_unix_ms || 0) > 0 && !!pane.weather.error
        text: pane.weather.error || ""
        summaryText: qsTr("Weather refresh failed · Previous reading retained")
        tone: "error"
    }

    WeatherHourlyForecast {
        weather: pane.weather
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
    }

    WeatherDailyForecast {
        weather: pane.weather
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
    }
}
