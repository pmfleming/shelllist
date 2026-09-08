import QtQuick
import QtTest
import Shelllist.Battery as Battery

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
            history: ({ points: [
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

    function test_forecastLimitAndSharedHover() {
        const card = createTemporaryObject(historyCard, testCase, {
            battery: { available: true, percentage: 60, charging: true, time_to_full_seconds: 3600,
                protection: { enabled: true, end_percent: 80 } }
        });
        verify(waitForRendering(card));
        const charge = findChild(card, "chargeHistoryGraph");
        const energy = findChild(card, "energyHistoryGraph");
        compare(card.forecast.seconds, 1800);
        compare(card.historyFraction, 0.5);
        compare(charge.historyFraction, energy.historyFraction);
        verify(findChild(charge, "chargeLimitLabel").visible);
        verify(findChild(card, "batteryHistoryEstimate").text.indexOf("80% limit") > 0);
        charge.hovered(0.1);
        compare(energy.hoverPosition, 0.1);
        verify(card.hoveredSample !== null);
        verify(card.hoveredEnergy !== null);
        energy.hovered(0.75);
        compare(charge.hoverPosition, 0.75);
        verify(findChild(card, "batteryHistoryHover").text.indexOf("Projected charge") === 0);
        energy.hovered(-1);
        compare(charge.hoverPosition, -1);
        card.battery = { available: true, percentage: 88, charging: false,
            protection: { enabled: true, end_percent: 80 } };
        compare(card.forecast.seconds, 0);
        compare(card.historyFraction, 1);
        verify(findChild(charge, "chargeLimitLabel").visible);
        compare(card.estimateText, "Charge limit reached");
        card.battery = { available: true, percentage: 60, charging: true, time_to_full_seconds: 234972 };
        compare(card.forecast.seconds, 0);
        compare(card.estimateText, "Estimating charge time…");
    }

    function test_contentAndPlotsStayInsideCard() {
        const card = createTemporaryObject(historyCard, testCase, { width: 340 });
        verify(card !== null);
        verify(waitForRendering(card));
        const charge = findChild(card, "chargeHistoryGraph");
        const energy = findChild(card, "energyHistoryGraph");
        verify(charge !== null && energy !== null);
        for (const graph of [charge, energy]) {
            const position = graph.mapToItem(card, 0, 0);
            verify(position.x >= 0 && position.y >= 0);
            verify(position.x + graph.width <= card.width);
            verify(position.y + graph.height <= card.height,
                "graph must not overflow the bottom of its card");
            const plot = findChild(graph, "batteryHistoryPlot");
            const plotPosition = plot.mapToItem(graph, 0, 0);
            verify(plotPosition.x >= 0 && plotPosition.y >= 0);
            verify(plotPosition.y + plot.height <= graph.height);
            verify(plot.width > 0 && plot.height > 0);
        }
        const chargePlot = findChild(charge, "batteryHistoryPlot");
        const energyPlot = findChild(energy, "batteryHistoryPlot");
        compare(chargePlot.mapToItem(card, 0, 0).x, energyPlot.mapToItem(card, 0, 0).x);
        compare(chargePlot.width, energyPlot.width, "tracks share the exact same time axis");
        const top = charge.mapToItem(card, 0, 0).y;
        verify(energy.mapToItem(card, 0, 0).y >= top + charge.height + card.contentSpacing);
    }
}
