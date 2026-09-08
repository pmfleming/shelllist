pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Column {
    id: pane

    required property ActivityController controller
    required property date now

    spacing: Ui.Theme.spacingMd

    GlanceWeatherCard {
        width: pane.width
        height: Math.max(88, Math.min(96, pane.height * 0.11))
        weather: pane.controller.activity.weather || ({
                available: false
            })
        now: pane.now
        onRequested: function (section) {
            pane.controller.requestTimeWeather(section);
        }
    }

    GlanceScheduleCard {
        width: pane.width
        height: Math.max(250, Math.min(320, pane.height * 0.38))
        controller: pane.controller
        now: pane.now
    }

    GlanceNotificationsCard {
        width: pane.width
        height: Math.max(170, pane.height - y)
        controller: pane.controller
        now: pane.now
    }
}
