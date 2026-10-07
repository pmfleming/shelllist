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
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
    }

    Ui.ThemeText {
        width: parent.width
        visible: Number(pane.weather.updated_unix_ms || 0) > 0 && !!pane.weather.error
        text: pane.weather.error || ""
        color: Ui.Theme.danger
        wrapMode: Text.Wrap
    }

    WeatherHourlyForecast {
        weather: pane.weather
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
        now: pane.now
    }

    WeatherDailyForecast {
        weather: pane.weather
        updating: pane.controller.activity.syncing
        active: pane.controller.uiActive
    }
}
