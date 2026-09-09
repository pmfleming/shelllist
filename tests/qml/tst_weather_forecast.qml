import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "WeatherForecast"
    when: windowShown
    width: 760
    height: 600
    visible: true

    function makeCard(name: string, properties: var): var {
        const component = Qt.createComponent("../../qml/Shelllist/Activity/" + name + ".qml");
        compare(component.status, Component.Ready, component.errorString());
        const card = createTemporaryObject(component, testCase, properties);
        verify(card !== null);
        return card;
    }

    function test_hourlyForecastAdvancesWithClock(): void {
        const start = Date.UTC(2026, 0, 1, 12);
        const hours = [0, 1, 2].map(function (offset) {
            return {
                time_unix_ms: start + offset * 3600000,
                temperature_c: 10 + offset,
                condition_code: 0,
                is_day: true
            };
        });
        const weather = {
            hourly: hours,
            utc_offset_seconds: 0
        };
        const card = makeCard("WeatherHourlyForecast", {
            weather: weather,
            now: new Date(start)
        });
        compare(card.points.length, 3);
        card.now = new Date(start + 3600000);
        compare(card.points.length, 2);
        compare(card.points[0].time_unix_ms, start + 3600000);
        compare(card.minimum, 11);
        compare(card.maximum, 12);
    }

    function test_locationCardSupportsKeyboardSelection(): void {
        const card = makeCard("WeatherLocationCard", {
            modelData: {
                id: "home",
                location: "Home",
                condition_code: 0
            },
            selectedId: "",
            now: new Date(),
            width: 220,
            height: 92
        });
        let selected = "";
        card.selected.connect(function (id) {
            selected = id;
        });
        card.forceActiveFocus();
        tryCompare(card, "activeFocus", true);
        keyClick(Qt.Key_Return);
        compare(selected, "home");
    }

    function test_forecastCardsAcceptEmptyWeather(): void {
        for (const name of ["WeatherHero", "WeatherDailyForecast", "WeatherMetrics"])
            makeCard(name, name === "WeatherHero" ? {
                weather: {},
                now: new Date()
            } : {
                weather: {}
            });
        makeCard("WeatherLocationRail", {
            locations: [],
            selectedId: "",
            now: new Date()
        });
        wait(10);
    }
}
