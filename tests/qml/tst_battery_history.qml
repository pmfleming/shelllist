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
    function luminance(color) {
        function channel(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4); }
        return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
    }
    function contrast(a, b) {
        const first = luminance(a), second = luminance(b);
        return (Math.max(first, second) + 0.05) / (Math.min(first, second) + 0.05);
    }
    function test_tracksAndPalette_data() {
        return [
            {tag: "light-narrow", scheme: Qt.Light, cardWidth: 340}
        ];
    }
    function test_tracksAndPalette(data) {
        Ui.Theme.previewColorScheme = data.scheme;
        tests.width = data.cardWidth;
        const card = make();
        const graph = findChild(card, "batteryTimelineGraph");
        const charge = findChild(card, "batteryHistoryPlot");
        const power = findChild(card, "batteryPowerPlot");
        verify(charge.y + charge.height < power.y);
        compare(charge.x, power.x);
        compare(charge.width, power.width);
        verify(power.y + power.height < findChild(graph, "historyNowLabel").y);
        verify(!graph.activeFocusOnTab);
        compare(findChild(card, "batteryChargingLegend").text, "Charging");
        compare(findChild(card, "batteryDischargingLegend").text, "Discharging");
        compare(findChild(card, "batteryPowerDirection").text, "Into battery");
        compare(findChild(card, "batteryHistoryPower").color, graph.chargingColor);
        const colors = [graph.lineColor, graph.chargingColor, graph.dischargingColor];
        compare(new Set(colors.map(String)).size, 3);
        colors.forEach(color => {
            compare(color.a, 1);
            verify(Math.max(color.r, color.g, color.b) - Math.min(color.r, color.g, color.b) < 0.26, "low-chroma foregrounds");
            verify(contrast(color, card.color) >= 4.5, "readings and bars remain readable in either theme");
        });
        const samples = graph.powerSeries.segments.reduce((all, segment) => all.concat(segment), []);
        const incoming = samples.find(p => p.value === 36);
        const outgoing = samples.find(p => p.value === 24);
        const inBar = power.barRect(incoming), outBar = power.barRect(outgoing);
        compare(inBar.y + inBar.height, power.height / 2);
        compare(outBar.y, power.height / 2);
        verify(inBar.height > 0 && outBar.height > 0);
        verify(graph.powerSeries.segments.length === 2, "missing wattage splits the series");
        verify(!findChild(card, "powerHistoryEmptyLabel").visible);
        // Capture the card and map child coordinates: the software test grabber
        // crops nested items using parent-local rather than scene coordinates.
        const origin = power.mapToItem(card, 0, 0);
        tryVerify(() => {
            const image = grabImage(card);
            return String(image.pixel(Math.round(origin.x + inBar.x + 2), Math.round(origin.y + inBar.y + inBar.height / 2))) === String(graph.chargingColor)
                && String(image.pixel(Math.round(origin.x + outBar.x + 2), Math.round(origin.y + outBar.y + outBar.height / 2))) === String(graph.dischargingColor);
        });
        const image = grabImage(card);
        const gapX = Math.round(origin.x + 3 + 0.4 * (power.width - 6));
        compare(image.pixel(gapX, Math.round(origin.y + power.height / 2 - 12)), card.color, "no bar in the missing interval");
    }
    function test_inspectionForecastAndThemeRepaint() {
        Ui.Theme.previewColorScheme = Qt.Dark;
        const card = make();
        const graph = findChild(card, "batteryTimelineGraph");
        const power = findChild(card, "batteryPowerPlot");
        const charge = findChild(card, "batteryHistoryPlot");
        const footer = findChild(card, "batteryHistoryInspection");
        mouseClick(power, power.width * 0.6, power.height / 2);
        verify(graph.inspecting);
        verify(graph.activeFocus);
        verify(footer.text.includes("36.0 W in"));
        keyClick(Qt.Key_Home);
        compare(graph.inspectionPosition, 0);
        verify(footer.text.includes("no flow"));
        keyClick(Qt.Key_Right);
        compare(graph.inspectionPosition, 0.025);
        keyClick(Qt.Key_Escape);
        verify(!graph.inspecting);
        mouseMove(card, 1, 1);
        tryCompare(graph, "hoverPosition", -1);
        verify(footer.text.includes("Observed time"));
        card.battery = Object.assign({}, card.battery, {forecast: {seconds: 18000, percentage: 89, target: 90, limit: 90}});
        tryVerify(() => graph.historyFraction < 1);
        verify(findChild(card, "historyForecastLabel").visible);
        mouseClick(charge, charge.width - 4, charge.height / 2);
        verify(footer.text.includes("Estimated"));
        verify(!footer.text.includes(" W"), "forecast never invents wattage");
        const oldColor = String(graph.chargingColor);
        Ui.Theme.previewColorScheme = Qt.Light;
        tryVerify(() => String(graph.chargingColor) !== oldColor);
        const sample = graph.powerSeries.segments.reduce((all, segment) => all.concat(segment), []).find(p => p.value === 36);
        const bar = power.barRect(sample);
        const origin = power.mapToItem(card, 0, 0);
        tryVerify(() => String(grabImage(card).pixel(Math.round(origin.x + bar.x + 2), Math.round(origin.y + bar.y + bar.height / 2))) === String(graph.chargingColor));
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
