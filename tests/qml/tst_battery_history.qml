import QtQuick
import QtTest
import Shelllist.Battery as Battery

TestCase {
    id: testCase
    name: "BatteryHistory"
    when: windowShown
    visible: true
    width: 540
    height: 480

    Component {
        id: historyCard
        Battery.BatteryHistoryCard {
            width: 500
            battery: ({ available: true, percentage: 89, charging: false })
            history: ({ points: [
                { timestamp_ms: 1788046659368, active_time_ms: 0,
                    continuous: false, percentage: 100, charging: false },
                { timestamp_ms: 1788047559368, active_time_ms: 900000,
                    continuous: true, percentage: 0, charging: false },
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
            minimumMaximum: 100
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

    function test_contentAndPlotsStayInsideCard_data() {
        return [{ tag: "normal", cardWidth: 500 }, { tag: "narrow", cardWidth: 340 }];
    }

    function test_contentAndPlotsStayInsideCard(data) {
        const card = createTemporaryObject(historyCard, testCase, { width: data.cardWidth });
        verify(card !== null);
        verify(waitForRendering(card));
        const charge = findChild(card, "chargeHistoryGraph");
        const full = findChild(card, "fullHistoryGraph");
        verify(charge !== null && full !== null);
        for (const graph of [charge, full]) {
            const position = graph.mapToItem(card, 0, 0);
            verify(position.x >= card.contentPadding);
            verify(position.y > card.headingHeight);
            verify(position.x + graph.width <= card.width - card.contentPadding + 1);
            verify(position.y + graph.height <= card.height - card.verticalContentPadding + 1,
                "graph must not overflow the bottom of its card");
            const plot = findChild(graph, "batteryHistoryPlot");
            const plotPosition = plot.mapToItem(graph, 0, 0);
            verify(plotPosition.x > 10, "leave room for the vertical scale");
            verify(plotPosition.y >= 27, "plot must stay below the label");
            verify(plotPosition.y + plot.height < graph.height - 8);
            verify(plot.width > 0 && plot.height > 0);
        }
        compare(charge.series.segments.length, 2);
        compare(charge.series.segments[1][0].x, 0.5);
        compare(full.series.maximum, 234972);
        compare(full.series.segments.length, 1);
        verify(full.maximumText.indexOf("65h") === 0, "large estimates need an honest scale");
        const top = charge.mapToItem(card, 0, 0).y;
        verify(full.mapToItem(card, 0, 0).y >= top + charge.height + card.contentSpacing);
    }
}
