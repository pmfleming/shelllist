import QtQuick
import QtTest
import Shelllist.Activity as Activity

TestCase {
    id: testCase
    name: "TimeWeatherSelection"

    Component {
        id: controllerComponent
        Activity.TimeWeatherController {}
    }

    function weather(id, location, timezone, home) {
        return { id: id, location: location, timezone: timezone, home: home,
            available: true, temperature_c: home ? 36 : 28 };
    }

    function makeController() {
        const controller = createTemporaryObject(controllerComponent, testCase, {
            activity: { world_clocks: [], weather_locations: [
                weather("okc", "Oklahoma City", "America/Chicago", true),
                weather("taipei", "Taipei", "Asia/Taipei", false)
            ] }
        });
        verify(controller !== null);
        controller.rebuildCityModel();
        return controller;
    }

    function test_weatherFollowsCitySelection() {
        const controller = makeController();
        compare(controller.selectedCity.label, "Oklahoma City");
        compare(controller.selectedWeather.id, "okc");
        controller.selectionModel.move(1);
        compare(controller.selectedCity.label, "Taipei");
        compare(controller.selectedWeather.id, "taipei");
        controller.selectionModel.move(-1);
        compare(controller.selectedCity.label, "Oklahoma City");
        compare(controller.selectedWeather.id, "okc");
    }

    function test_snapshotChangesCityWithoutChangingIndex() {
        const controller = makeController();
        controller.applySnapshot({ activity: { world_clocks: [], weather_locations: [
            weather("taipei", "Taipei", "Asia/Taipei", false)
        ] } });
        compare(controller.selectionModel.selectedIndex, 0);
        compare(controller.selectedCity.label, "Taipei");
        compare(controller.selectedWeather.id, "taipei");
    }

    function test_clockOnlyCityConsumesUpdatedNativeLunarMetadata() {
        const controller = makeController();
        const clock = { timezone: "Asia/Tokyo", label: "Tokyo", utc_offset_seconds: 32400 };
        for (const fraction of [0.25, 0.75]) {
            controller.applySnapshot({ activity: { world_clocks: [clock], weather_locations: [],
                lunar: { fraction: fraction, approximate: true } } });
            compare(controller.selectedCity.label, "Tokyo");
            compare(controller.selectedCity.weather, null);
            compare(controller.selectedCity.lunar.fraction, fraction);
        }
        controller.applySnapshot({ activity: { world_clocks: [clock], weather_locations: [], lunar: null } });
        compare(controller.selectedCity.lunar, null);
    }

    function test_emptyFilterClearsWeatherSelection() {
        const controller = makeController();
        controller.filterText = "no matching city";
        verify(!controller.hasSelection);
        compare(controller.weatherLocationId, "");
        controller.filterText = "Taipei";
        verify(controller.hasSelection);
        compare(controller.selectedWeather.id, "taipei");
    }

}
