import QtQuick
import QtTest
import Shelllist.Battery as Battery
import Shelllist.Ui as Ui

TestCase {
    id: testCase
    name: "BatteryHistory"
    when: windowShown
    visible: true
    width: 540
    height: 720

    Component {
        id: historyCard
        Battery.BatteryHistoryCard {
            width: 500
            battery: ({ available: true, percentage: 89, charging: false })
            history: ({ energy: { bars: [{ x0: 0, x1: 0.5, value: 2.5, observedMs: 900000 }], totalWh: 2.5, maximum: 2.5, intervalMs: 900000, activeDurationMs: 1800000 }, points: [
                { timestamp_ms: 1788046659368, active_time_ms: 0,
                    continuous: false, percentage: 100, charging: false, plugged: false, power_watts: 8 },
                { timestamp_ms: 1788047559368, active_time_ms: 900000,
                    continuous: true, percentage: 0, charging: false, plugged: false, power_watts: 12 },
                { timestamp_ms: 1788646507951, active_time_ms: 900000,
                    continuous: false, percentage: 89, charging: true, time_to_full_seconds: 717 },
                { timestamp_ms: 1788647407951, active_time_ms: 1800000,
                    continuous: true, percentage: 100, charging: true, time_to_full_seconds: 234972 }
            ] })
        }
    }

    Component {
        id: edgeGraph
        Battery.BatteryHistoryGraph {
            width: 300
            height: graphHeight
            lineColor: "#ff0000"
            points: [
                { timestamp_ms: 1000, active_time_ms: 0, percentage: 100, continuous: false },
                { timestamp_ms: 61000, active_time_ms: 60000, percentage: 0, continuous: false }
            ]
        }
    }

    function hasRed(image, left, top, right, bottom) {
        for (let y = top; y < bottom; ++y) {
            for (let x = left; x < right; ++x) {
                if (image.red(x, y) > image.green(x, y) + 80
                        && image.red(x, y) > image.blue(x, y) + 80)
                    return true;
            }
        }
        return false;
    }

    function test_isolatedZeroAndFullSamplesAreVisible() {
        if (Screen.devicePixelRatio !== 1) {
            skip("QtTest grabImage crops to logical bounds on high-DPI screens");
            return;
        }
        const graph = createTemporaryObject(edgeGraph, testCase);
        verify(graph !== null);
        verify(waitForRendering(graph));
        const plot = findChild(graph, "batteryHistoryPlot");
        tryVerify(function () {
            const image = grabImage(graph);
            const origin = plot.mapToItem(graph, 0, 0);
            const left = Math.floor(origin.x);
            const top = Math.floor(origin.y);
            const right = Math.ceil(origin.x + plot.width);
            const bottom = Math.ceil(origin.y + plot.height);
            return hasRed(image, left, top, left + 6, top + 6)
                && hasRed(image, right - 6, bottom - 6, right, bottom);
        });
    }

    function test_forecastAndHoverFollowPowerSource() {
        const card = createTemporaryObject(historyCard, testCase, {
            battery: { available: true, percentage: 60, charging: true, plugged: true,
                forecast: { limit: 80, target: 80, percentage: 60, seconds: 1800 } }
        });
        verify(waitForRendering(card));
        const graph = findChild(card, "batteryTimelineGraph");
        compare(graph.historyFraction, 0.5);
        verify(findChild(graph, "chargeLimitLabel").visible);
        compare(card.estimateText, "to 80% limit");
        graph.hovered(0.1);
        verify(graph.hoveredSample !== null);
        verify(graph.hoveredPower !== null);
        verify(graph.hoverText.indexOf("W") > 0);
        graph.hovered(0.75);
        verify(graph.hoverText.indexOf("Estimated") === 0);
        card.battery = { available: true, percentage: 85, plugged: false,
            forecast: { limit: 80, target: 0, percentage: 85, seconds: 12600 } };
        compare(graph.forecast.target, 0);
        compare(card.estimateText, "to empty");
        verify(graph.hoverText.indexOf("to empty") > 0);
        card.battery = { available: true, percentage: 80, plugged: true,
            forecast: { limit: 80, target: 80, percentage: 80, seconds: 0, status: "limit-reached" } };
        compare(graph.historyFraction, 1);
        compare(card.estimateText, "Charge limit reached");
        card.battery = { available: true, percentage: 60, charging: true, plugged: true,
            forecast: { limit: null, target: 100, percentage: 60, seconds: 0, estimating: true } };
        compare(card.estimateText, "Estimating…");
        compare(graph.historyFraction, 1);
    }

    function test_rangeSelectionAndMissingPower() {
        const card = createTemporaryObject(historyCard, testCase, {
            history: { points: [
                { timestamp_ms: 1000, active_time_ms: 0, percentage: 100, power_watts: 20, power_valid: true },
                { timestamp_ms: 25201000, active_time_ms: 25200000, percentage: 80, power_watts: 0, power_valid: false },
                { timestamp_ms: 28801000, active_time_ms: 28800000, percentage: 60, power_watts: 0, power_valid: true, continuous: true }
            ] }
        });
        verify(waitForRendering(card));
        const graph = findChild(card, "batteryTimelineGraph");
        compare(graph.points.length, 2);
        compare(graph.powerSeries.segments.length, 1);
        compare(graph.powerSeries.segments[0].length, 1);
        compare(graph.powerSeries.segments[0][0].value, 0);
        const ranges = findChild(card, "batteryHistoryRange");
        ranges.choose(1);
        compare(card.range, "24");
        compare(graph.points.length, 3);
        compare(graph.powerSeries.segments.length, 2);
        ranges.choose(0);
        compare(graph.points.length, 2);
        card.battery = { available: true, percentage: 59, history: { current_point:
            { timestamp_ms: 28831000, active_time_ms: 28830000, percentage: 59,
                power_watts: 10, power_valid: true, continuous: true } } };
        compare(graph.points.length, 3);
        compare(graph.series.segments[0][2].value, 59, "live charge must reach the Now marker");
    }

    function test_emptyHistory() {
        const card = createTemporaryObject(historyCard, testCase, {
            width: 300, history: { points: [] }, battery: { available: false }
        });
        verify(waitForRendering(card));
        const graph = findChild(card, "batteryTimelineGraph");
        compare(card.estimateText, "Unavailable");
        verify(findChild(graph, "historyEmptyLabel").visible);
        compare(graph.historyFraction, 1);
        compare(graph.hoveredSample, null);
        compare(graph.hoveredPower, null);
        card.battery = { available: true, percentage: 85,
            forecast: { limit: null, target: 0, percentage: 85, seconds: 12600 } };
        verify(!findChild(graph, "historyEmptyLabel").visible);
        verify(graph.historyFraction > 0 && graph.historyFraction < 1);
    }

    function test_contentAndPlotStayInsideCard_data() {
        return [{ tag: "narrow", width: 300 }, { tag: "compact", width: 340 },
            { tag: "normal", width: 500 }];
    }

    function test_contentAndPlotStayInsideCard(data) {
        const card = createTemporaryObject(historyCard, testCase, { width: data.width });
        verify(card !== null);
        verify(waitForRendering(card));
        const graph = findChild(card, "batteryTimelineGraph");
        const position = graph.mapToItem(card, 0, 0);
        verify(position.x >= 0 && position.y >= 0);
        verify(position.x + graph.width <= card.width);
        verify(position.y + graph.height <= card.height);
        const plot = findChild(graph, "batteryHistoryPlot");
        verify(plot.width > 0 && plot.height > 0);
        verify(plot.y + plot.height <= graph.height);
        const initialHeight = card.height;
        graph.hovered(0.1);
        wait(0);
        compare(card.height, initialHeight, "hover must not move the chart or application list");
    }
}
