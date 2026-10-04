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
