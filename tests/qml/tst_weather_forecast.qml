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

    function test_heroUsesFullWidth_data(): var {
        return [
            { tag: "compact", cardWidth: 360 },
            { tag: "standard", cardWidth: 545 },
            { tag: "wide", cardWidth: 760 }
        ];
    }

    function test_heroUsesFullWidth(data: var): void {
        const card = makeCard("WeatherHero", {
            width: data.cardWidth,
            weather: {
                location: "Amsterdam with a very long location name".repeat(3),
                condition: "Partly cloudy with occasional sunny spells",
                condition_code: 2,
                temperature_c: -18,
                high_c: -14,
                low_c: -19,
                apparent_temperature_c: -21,
                precipitation_probability: 84,
                wind_direction_degrees: 225,
                wind_speed_kmh: 19,
                updated_unix_ms: Date.UTC(2026, 0, 1, 15, 35)
            }
        });
        wait(10);
        const temperature = findChild(card, "weatherHeroTemperature");
        const icon = findChild(card, "weatherHeroIcon");
        const location = findChild(card, "weatherHeroLocation");
        const condition = findChild(card, "weatherHeroCondition");
        const metrics = findChild(card, "weatherHeroMetrics");
        verify(location.truncated);
        compare(condition.text, card.weather.condition);
        verify(icon.x + icon.width < condition.x);
        verify(condition.width > 0);
        verify(condition.x + condition.width < temperature.x);
        for (const item of [icon, condition, temperature]) {
            verify(item.y >= 0, item.objectName + " y=" + item.y + " height=" + item.height);
            verify(item.y + item.height <= item.parent.height, item.objectName + " exceeds summary height");
            verify(item.parent.y + item.y + item.height <= metrics.y);
        }
        verify(card.now === undefined);
        compare(metrics.width, card.width - 36);
        for (let i = 0; i < 3; ++i) {
            const metric = findChild(card, "weatherHeroMetric" + i);
            verify(metric !== null);
            verify(Math.abs(metric.width - metrics.width / 3) < 0.01);
            tryVerify(function () {
                return Math.abs(metric.x - i * metric.width) < 1;
            });
        }
        verify(metrics.y + metrics.height < card.height);
    }

    function test_forecastCardsAcceptEmptyWeather(): void {
        for (const name of ["WeatherHero", "WeatherDailyForecast", "WeatherMetrics"])
            makeCard(name, { weather: {} });
        makeCard("WeatherLocationRail", {
            locations: [],
            selectedId: "",
            now: new Date()
        });
        wait(10);
    }
}
