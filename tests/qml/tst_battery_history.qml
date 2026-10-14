pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Battery as Battery
import Shelllist.Ui as Ui

TestCase {
    id: tests
    name: "BatteryHistory"
    when: windowShown
    visible: true
    width: 453
    height: 800

    Component {
        id: factory
        Battery.BatteryHistoryCard {}
    }
    function init() { failOnWarning(/.*/); }
    function cleanup() { Ui.Theme.previewColorScheme = Qt.Unknown; }
    function points() {
        return [
            {percentage: 88, power_watts: 0, charging: false},
            {percentage: 76, power_watts: 24, charging: false},
            {percentage: null, power_watts: null, charging: false},
            {percentage: 89, power_watts: 36, charging: true},
            {percentage: 87, power_watts: 0, charging: false},
            {percentage: 89, power_watts: 1.8, charging: true}
        ].map((p, i) => Object.assign(p, {timestamp_ms: 86400000 + i * 3600000,
            active_time_ms: i * 3600000, continuous: i !== 0, power_valid: true}));
    }
    function make() {
        const card = createTemporaryObject(factory, tests, {
            history: {points: points()},
            battery: {available: true, percentage: 89, plugged: true, charging: true,
                power_available: true, power_watts: 1.8,
                forecast: {seconds: 0, target: 90, limit: 90}}
        });
        verify(card !== null);
        verify(waitForRendering(card));
        return card;
    }
    function test_unknownZeroAndWarningStayDistinct() {
        const card = make();
        const graph = findChild(card, "batteryTimelineGraph");
        card.history = {points: []};
        tryCompare(findChild(card, "powerHistoryEmptyLabel"), "visible", true);
        verify(findChild(card, "historyEmptyLabel").visible);
        card.battery = Object.assign({}, card.battery, {percentage: null, power_available: false});
        compare(graph.currentPercentage, -1, "unknown charge is not a fabricated zero");
        compare(findChild(card, "batteryHistoryPower").text, "— W");
        compare(findChild(card, "batteryPowerDirection").text, "Unavailable");
        card.battery = Object.assign({}, card.battery, {percentage: 0, power_available: true, power_watts: 0, warning: true});
        compare(graph.currentPercentage, 0);
        compare(graph.lineColor, Ui.Theme.warning);
        compare(findChild(card, "batteryHistoryPower").text, "0.0 W");
        compare(findChild(card, "batteryPowerDirection").text, "No battery flow");
        card.history = {points: [points()[0]]};
        tryCompare(findChild(card, "powerHistoryEmptyLabel"), "visible", false);
        compare(graph.powerSeries.segments[0][0].value, 0);
    }
}
