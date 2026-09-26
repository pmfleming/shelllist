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
        id: edgeGraph
        Battery.BatteryHistoryGraph {
            width: 300
            height: graphHeight
            lineColor: "#ff0000"
            points: [
                {
                    timestamp_ms: 1000,
                    active_time_ms: 0,
                    percentage: 100,
                    continuous: false
                },
                {
                    timestamp_ms: 61000,
                    active_time_ms: 60000,
                    percentage: 0,
                    continuous: false
                }
            ]
        }
    }

    function hasRed(image, left, top, right, bottom) {
        for (let y = top; y < bottom; ++y) {
            for (let x = left; x < right; ++x) {
                if (image.red(x, y) > image.green(x, y) + 80 && image.red(x, y) > image.blue(x, y) + 80)
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
            return hasRed(image, left, top, left + 6, top + 6) && hasRed(image, right - 6, bottom - 6, right, bottom);
        });
    }

    function test_gapDashesOnlyConnectChargeReadings() {
        if (Screen.devicePixelRatio !== 1) {
            skip("QtTest grabImage crops to logical bounds on high-DPI screens");
            return;
        }
        for (const levels of [[40, 70], [70, 40]]) {
            const graph = createTemporaryObject(edgeGraph, testCase);
            graph.points = [
                {
                    timestamp_ms: 1000,
                    active_time_ms: 0,
                    percentage: levels[0],
                    continuous: false
                },
                {
                    timestamp_ms: 61000,
                    active_time_ms: 60000,
                    percentage: levels[0],
                    continuous: true
                },
                {
                    timestamp_ms: 121000,
                    active_time_ms: 60000,
                    percentage: levels[1],
                    continuous: false
                },
                {
                    timestamp_ms: 181000,
                    active_time_ms: 120000,
                    percentage: levels[1],
                    continuous: true
                }
            ];
            verify(waitForRendering(graph));
            const plot = findChild(graph, "batteryHistoryPlot");
            compare(graph.series.breaks.length, 1);
            tryVerify(function () {
                const image = grabImage(graph);
                const origin = plot.mapToItem(graph, 0, 0);
                const middle = Math.round(origin.x + plot.width / 2);
                const top = origin.y + 3;
                const height = plot.height - 6;
                return hasRed(image, middle - 2, Math.ceil(top + height * 0.35), middle + 3, Math.floor(top + height * 0.55)) && !hasRed(image, middle - 2, Math.ceil(top), middle + 3, Math.floor(top + height * 0.25)) && !hasRed(image, middle - 2, Math.ceil(top + height * 0.65), middle + 3, Math.floor(top + height));
            }, 5000, "gap dashes stay between the old and new charge levels");
            graph.destroy();
        }
    }

}
