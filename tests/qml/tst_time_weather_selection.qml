pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Activity as Activity

TestCase {
    id: testCase
    name: "TimeWeatherSelection"
    when: windowShown
    visible: true
    width: 800
    height: 720

    Component {
        id: controllerComponent
        Activity.TimeWeatherController {}
    }
    function weather(id, location, timezone, home) {
        return {
            id: id,
            location: location,
            timezone: timezone,
            home: home,
            available: true,
            temperature_c: home ? 36 : 28
        };
    }

    function makeController() {
        const controller = createTemporaryObject(controllerComponent, testCase, {
            activity: {
                world_clocks: [],
                weather_locations: [weather("okc", "Oklahoma City", "America/Chicago", true), weather("taipei", "Taipei", "Asia/Taipei", false)]
            }
        });
        verify(controller !== null);
        controller.rebuildCityModel();
        return controller;
    }

    function test_timeHeroFitsReadableMetricDetailsAtNarrowWidths() {
        const component = Qt.createComponent("../../qml/Shelllist/Activity/TimeWeatherTimePane.qml");
        compare(component.status, Component.Ready, component.errorString());
        const pane = createTemporaryObject(component, testCase, {
            width: 400, height: 600,
            city: {label: "Example city", lunar: {phase: "waxing-gibbous", fraction: 0.8, illumination_percent: 80}},
            now: new Date(2026, 8, 29, 12, 30)
        });
        const hero = findChild(pane, "timeHero");
        const metrics = findChild(pane, "timeHeroMetrics");
        const detail = findChild(pane, "timeMetricDetail-moon");
        tryVerify(() => metrics.height > 0);
        verify(detail.font.pixelSize >= 11);
        verify(hero.stacked);
        verify(metrics.y + metrics.height <= hero.height);
        pane.width = 800;
        tryCompare(hero, "stacked", false);
        tryVerify(() => metrics.y + metrics.height <= hero.height);
    }
    function test_snapshotChangesCityWithoutChangingIndex() {
        const controller = makeController();
        controller.applySnapshot({
            activity: {
                world_clocks: [],
                weather_locations: [weather("taipei", "Taipei", "Asia/Taipei", false)]
            }
        });
        compare(controller.selectionModel.selectedIndex, 0);
        compare(controller.selectedCity.label, "Taipei");
        compare(controller.selectedWeather.id, "taipei");
    }

}
