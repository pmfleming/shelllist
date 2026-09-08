pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.DetailFlickable {
    id: pane

    required property ActivityController controller
    required property date now
    property bool showLocationRail: true
    readonly property var weather: controller.selectedWeather

    WeatherLocationRail {
        visible: pane.showLocationRail
        height: visible ? 108 : 0
        locations: pane.controller.weatherLocations
        selectedId: pane.weather.id || ""
        now: pane.now
        onSelected: function (locationId) {
            pane.controller.selectWeatherLocation(locationId);
        }
    }

    WeatherHero {
        weather: pane.weather
        now: pane.now
    }

    WeatherHourlyForecast {
        weather: pane.weather
        now: pane.now
    }

    WeatherDailyForecast {
        weather: pane.weather
    }

    WeatherMetrics {
        weather: pane.weather
    }
}
