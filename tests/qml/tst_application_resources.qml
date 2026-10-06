pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "../../launcher" as Apps
import "../../launcher/AppApi.js" as Api

DaemonTestCase {
    id: tests
    name: "ApplicationResources"
    when: windowShown
    visible: true
    width: 1250
    height: 900

    Component {
        id: factory
        Ui.ProviderChooserSurface {
            width: tests.width
            height: tests.height
            chooserController: Apps.ApplicationController { id: controller }
            listComponent: Ui.ChooserListPane {
                chooserController: controller
                powerVisible: false
                resultModel: controller.filteredResultsModel
                rowDelegate: Rectangle { implicitWidth: 300; implicitHeight: 40 }
            }
            detailsComponent: Apps.ApplicationResourcesPage {
                controller: controller
                application: controller.selectedApplication || ({})
                uiScale: 1
            }
        }
    }
    function fixture() {
        return {
            id: "resources-test", name: "Resource test", kind: "desktop-application", revision: 1,
            running: true, focused: false, instances: [], desktop_actions: [], category: "shell",
            cpu_percent_of_machine: 0, memory_bytes: 78852915, memory_swap_bytes: 0,
            gpu_busy_percent: 0, gpu_memory_resident_bytes: 276824064, gpu_memory_allocated_bytes: 276824064,
            disk_space_total_bytes: 6400000, disk_space_permanent_bytes: 6300000, disk_space_temporary_bytes: 100000,
            referenced_file_disk_bytes: 4096, referenced_file_temporary_bytes: 0,
            disk_read_bytes_per_second: 0, disk_write_bytes_per_second: 0,
            network_receive_bytes_per_second: 0, network_transmit_bytes_per_second: 0,
            energy_source: "rapl", energy_confidence: "low", estimated_app_power_watts: 0.004,
            measurement: {coverage: 1, memory_source: "pss", gpu_available: true, storage_available: true,
                disk_space_scope: "identified-app-directories", referenced_files_available: true,
                network_connections_available: true, network_bytes_available: false,
                sample_interval_ms: 2000, attribution_method: "application-cgroup"}
        };
    }
    function init() { failOnWarning(/.*/); calls = []; width = 1250; height = 900; }
    function historyCalls() { return calls.filter(call => call.method === Api.methods.history).length; }
    function make() {
        const panel = createTemporaryObject(factory, tests);
        verify(panel !== null);
        const controller = panel.chooserController;
        controller.activateUiState("1");
        controller.replaceProviderResults([controller.provider.resultFor(fixture())], true);
        tryVerify(() => controller.hasSelection && panel.listItem !== null);
        panel.listItem.focusList();
        keyClick(Qt.Key_Right);
        tryVerify(() => panel.detailsItem !== null);
        wait(0);
        controller.detailsTab = "resources";
        tryVerify(() => controller.historyInFlight);
        seedHistory(controller);
        return panel;
    }
    function seedHistory(controller) {
        const start = controller.historyWindowStartMs;
        const end = controller.historyWindowEndMs;
        const metric = {available: true, mean: 0, peak: 0, observed_ms: end - start, coverage: 1};
        const metrics = {
            cpu_percent_of_machine: metric,
            memory_bytes: Object.assign({}, metric, {mean: 78852915, peak: 79000000}),
            gpu_busy_percent: metric,
            gpu_memory_resident_bytes: Object.assign({}, metric, {mean: 276824064, peak: 280000000}),
            disk_read_bytes_per_second: Object.assign({}, metric, {mean: 100, peak: 400, observed_ms: (end - start) / 2}),
            disk_write_bytes_per_second: metric,
            average_power_watts: Object.assign({}, metric, {mean: 0.01, peak: 0.38})
        };
        const point = Object.assign(fixture(), {timestamp_ms: end - 15000, duration_ms: 15000,
            average_power_watts: 0.01, coverage: 1, sample_count: 7,
            availability: {cpu: true, memory: true, gpu: true, energy: true, disk_space: true, referenced_files: true, storage: true, network_bytes: false}});
        controller.applyResourceHistory(controller.activeHistoryRequestId, {
            target_id: controller.selectedResult.id, points: [point], has_more: false, next_cursor: "fixture",
            summary: {window_start_ms: start, window_end_ms: end, revision: "fixture", weighting: "observed-duration", metrics: metrics}
        });
    }
    function field(panel) { return findChild(panel, "applicationHistoryRange"); }
    function card(panel, name) { const value = findChild(panel, name); verify(value !== null, name); return value; }
    function test_rangeTransactionAndReadOnlyTraversal() {
        const panel = make();
        const c = panel.chooserController;
        const range = field(panel);
        keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.currentTarget, range);
        compare(panel.detailsNavigation.availableFields().length, 1, "Cards, metadata and charts are not field stops");
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget, range, "Reverse browse wraps to the sole editable field");
        const before = historyCalls();
        keyClick(Qt.Key_Right);
        compare(c.historyRange, "30m", "Right does not start editing");
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(range.displayedValue, "2h");
        compare(c.historyRange, "30m");
        compare(historyCalls(), before, "No query before save");
        keyClick(Qt.Key_Escape);
        compare(range.displayedValue, "30m");
        compare(historyCalls(), before);
        verify(panel.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        compare(c.historyRange, "2h");
        compare(historyCalls(), before + 1);
        compare(c.resourceHistorySummary, null, "No stale totals from the previous range");
        verify(panel.detailsNavigation.browsing);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(c.historyRange, "24h");
        compare(historyCalls(), before + 2);
        compare(panel.detailsNavigation.currentTarget, range);
        verify(panel.detailsNavigation.editing, "Save and reverse-wrap continues editing");
        keyClick(Qt.Key_Left);
        keyClick(Qt.Key_Tab);
        compare(c.historyRange, "2h");
        compare(historyCalls(), before + 3);
        verify(panel.detailsNavigation.editing);
        keyClick(Qt.Key_Escape);
        compare(range.value, c.historyRange, "Source binding survives transactions");
    }
    function test_pointerDraftAndListDepartureDiscard() {
        const panel = make();
        const c = panel.chooserController;
        const range = field(panel);
        const before = historyCalls();
        mouseClick(findChild(range, "segment-24h"));
        verify(panel.detailsNavigation.editing);
        compare(range.displayedValue, "24h");
        compare(c.historyRange, "30m");
        compare(historyCalls(), before);
        panel.listItem.focusList();
        tryVerify(() => !range.editSession.active);
        compare(range.displayedValue, "30m");
        compare(historyCalls(), before, "Leaving the field cannot publish its draft");
    }
    function test_scopedValuesAndUnavailableAreNotZero() {
        const panel = make();
        compare(card(panel, "applicationPower").valueText, "<0.01 W");
        verify(card(panel, "applicationPeriodEnergy").valueText.indexOf("≈ 5.00 mWh") >= 0);
        verify(card(panel, "applicationDiskFootprint").detailText.indexOf("Installation and shared dependencies not measured") >= 0);
        verify(card(panel, "applicationDiskFootprint").detailText.indexOf("Temporary:") >= 0);
        verify(card(panel, "applicationReferencedFiles").text.indexOf("not added") >= 0);
        const disk = card(panel, "applicationIo_disk_read_bytes_per_second");
        compare(disk.valueText, "0 B/s");
        verify(disk.available);
        verify(disk.detailText.indexOf("15.0 min observed / 30.0 min") >= 0);
        const network = card(panel, "applicationIo_network_receive_bytes_per_second");
        verify(!network.available);
        compare(findChild(network, "resourceValue").text, "—");
        const chart = card(panel, "applicationResourceTimeline");
        compare(chart.lanes.length, 5, "Overview and history are combined, not duplicated");
        verify(chart.lanes[0].series[0].valueText.indexOf("0.0%") >= 0);
        verify(chart.lanes[3].unavailableText.indexOf("unavailable; not zero") >= 0);
        verify(!card(panel, "resourcePlot_network").visible, "Unsupported plots collapse instead of graphing zero");
        compare(card(panel, "resourcePlot_memory").chartStyle, "steps");
        compare(card(panel, "resourcePlot_storage").chartStyle, "columns");
        compare(card(panel, "resourcePlot_activity").chartStyle, "lines");
        compare(card(panel, "resourcePlot_energy").chartStyle, "area");
        verify(card(panel, "resourceCoverage_storage").text.indexOf("↓ R 15m/30m") >= 0);
        verify(card(panel, "resourceCoverage_storage").text.indexOf("↑ W 30m/30m") >= 0, "Different directional coverage is not collapsed");
        verify(chart.timeLabel(4) !== "Now", "Retained window ends are timestamps, never fake live samples");
    }
    function test_retainedAndMissingMetricStates() {
        const panel = make();
        const c = panel.chooserController;
        const stopped = Object.assign(fixture(), {running: false});
        c.replaceProviderResults([c.provider.resultFor(stopped)], false);
        tryVerify(() => card(panel, "applicationResourceSnapshotStatus").text.indexOf("App stopped") >= 0);
        verify(card(panel, "applicationPower").accessibleLabel.indexOf("Last observed") >= 0);
        verify(card(panel, "applicationMemoryDetails").text.indexOf("Source not recorded") >= 0, "Historical samples do not carry a PSS/RSS source");
        c.resourceHistory = [];
        verify(card(panel, "applicationResourceSnapshotStatus").text.indexOf("no retained measurements") >= 0);
        verify(!card(panel, "applicationPower").available);
        verify(!card(panel, "applicationRam").available);
        const partial = fixture();
        partial.gpu_memory_resident_bytes = null;
        partial.memory_bytes = null;
        c.replaceProviderResults([c.provider.resultFor(partial)], false);
        verify(!card(panel, "applicationGpuMemory").available, "Capability alone cannot turn null into zero");
        verify(!card(panel, "applicationRam").available);
    }
    function test_measurementCommandIsReadOnlyAndDoesNotRequestHistory() {
        const panel = make();
        panel.detailsItem.width = 350;
        wait(0);
        const range = field(panel);
        const details = card(panel, "applicationMeasurementDetails");
        const command = card(panel, "applicationMeasurementDetailsCommand");
        const before = historyCalls();
        verify(!details.visible);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_H, Qt.AltModifier);
        tryVerify(() => details.visible);
        wait(20);
        compare(panel.detailsNavigation.availableFields().length, 1);
        compare(panel.detailsNavigation.currentTarget, range);
        tryVerify(() => {
            const heading = details.revealTarget;
            const y = heading.mapToItem(panel.detailsItem.contentItem, 0, 0).y;
            return y >= panel.detailsItem.contentY && y + heading.height <= panel.detailsItem.contentY + panel.detailsItem.height;
        }, 1000, "Disclosure heading is revealed, not the bottom of its long explanation");
        keyClick(Qt.Key_PageDown);
        tryVerify(() => panel.detailsItem.contentY > 0);
        const previousScroll = panel.detailsItem.contentY;
        keyClick(Qt.Key_PageUp);
        tryVerify(() => panel.detailsItem.contentY < previousScroll);
        keyClick(Qt.Key_H, Qt.AltModifier);
        tryVerify(() => !details.visible);
        panel.detailsItem.revealItem(command);
        wait(0);
        mouseClick(command);
        tryVerify(() => details.visible);
        compare(historyCalls(), before, "Disclosure has no backend side effects");
        keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.currentTarget, range);
        keyClick(Qt.Key_Tab, Qt.ShiftModifier);
        compare(panel.detailsNavigation.currentTarget, range);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_H, Qt.AltModifier);
        verify(details.visible, "The menu blocks underlying command chords");
        keyClick(Qt.Key_Escape);
        tryVerify(() => !panel.detailsNavigation.commandMenuOpen);
        verify(details.visible, "Closing the shared menu does not hide details");
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_Return);
        tryVerify(() => !panel.detailsNavigation.commandMenuOpen && !details.visible);
        compare(historyCalls(), before, "Named disclosure is also read-only");
    }
    function test_loadingAndZeroComposition() {
        const panel = make();
        const c = panel.chooserController;
        const zero = Object.assign(fixture(), {disk_space_total_bytes: 0, disk_space_permanent_bytes: 0, disk_space_temporary_bytes: 0});
        c.replaceProviderResults([c.provider.resultFor(zero)], false);
        compare(card(panel, "applicationDiskComposition").fraction, 0);
        compare(card(panel, "applicationDiskFootprint").valueText, "0 B");
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        keyClick(Qt.Key_Return);
        verify(c.historyInFlight);
        verify(card(panel, "applicationPeriodEnergy").valueText.indexOf("Loading") >= 0);
        verify(!card(panel, "resourcePlot_energy").visible, "No stale plot while requesting another range");
        compare(card(panel, "applicationPower").valueText, "<0.01 W", "Latest snapshot remains separate");
    }
    Component {
        id: drawingFactory
        Canvas {
            width: 100; height: 60
            property bool area: false
            onPaint: {
                const context = getContext("2d");
                context.reset();
                context.fillStyle = "white";
                context.fillRect(0, 0, width, height);
                context.strokeStyle = "red";
                context.fillStyle = "blue";
                context.lineWidth = 2;
                Ui.ChartDrawing.series(context, [[], [{x: 10, y: 10}, {x: 30, y: 10}],
                    [{x: 70, y: 10}, {x: 90, y: 10}], [{x: 50, y: 25}]], 50, area ? "green" : null, true);
            }
        }
    }
    function test_sharedChartPaths_data() {
        return [{tag: "line", area: false}, {tag: "area", area: true}];
    }
    function test_sharedChartPaths(data) {
        const chart = createTemporaryObject(drawingFactory, tests, {area: data.area});
        // QtTest's Canvas grab uses device pixels, including fractional scales.
        const pixel = (image, x, y) => image.pixel(Math.floor(x * chart.Screen.devicePixelRatio), Math.floor(y * chart.Screen.devicePixelRatio));
        tryVerify(() => pixel(grabImage(chart), 20, 10).g < 0.1);
        const pixels = grabImage(chart);
        compare(pixel(pixels, 20, 10), Qt.color("red"), "Observed segment is stroked");
        compare(pixel(pixels, 20, 30), Qt.color(data.area ? "green" : "white"), "Null fill draws only a line");
        compare(pixel(pixels, 50, 10), Qt.color("white"), "Missing intervals are not bridged");
        compare(pixel(pixels, 50, 30), Qt.color("white"), "Area fill also preserves gaps");
        compare(pixel(pixels, 50, 25), Qt.color("blue"), "Isolated dots retain the caller's fill style");
    }
    function test_chartIntervalsAndIndependentAvailability() {
        const panel = make();
        const c = panel.chooserController;
        const end = c.historyWindowEndMs;
        const point = c.resourceHistory[0];
        c.resourceHistory = [Object.assign({}, point, {timestamp_ms: end - 30000}),
            Object.assign({}, point, {timestamp_ms: end - 15000, gpu_memory_resident_bytes: null, disk_write_bytes_per_second: null}),
            Object.assign({}, point, {timestamp_ms: end})];
        const memory = card(panel, "resourcePlot_memory");
        compare(memory.segments[0].length, 1, "RAM remains measured");
        compare(memory.segments[1].length, 2, "GPU resident trace breaks independently");
        verify(memory.yFor(0, 0) < memory.height - memory.series.length * 4 * memory.uiScale, "Per-series gap bands cannot obscure a valid zero trace");
        const disk = card(panel, "resourcePlot_storage");
        compare(disk.segments[0].length, 1);
        compare(disk.segments[1].length, 2);
        c.resourceHistory = c.resourceHistory.map(p => Object.assign({}, p, {gpu_memory_resident_bytes: undefined}));
        compare(memory.segments[1].length, 0, "Legacy retained points need no new collector");
        verify(card(panel, "applicationGpuMemory").available, "Snapshot survives missing GPU history");
    }
    function test_compactGeometry() {
        const panel = make();
        const c = panel.chooserController;
        const active = fixture();
        active.measurement.network_bytes_available = true;
        c.replaceProviderResults([c.provider.resultFor(active)], false);
        const end = c.historyWindowEndMs;
        const start = c.historyWindowStartMs;
        const point = c.resourceHistory[0];
        const bucket = (end - start) / 24;
        c.resourceHistory = Array.from({length: 24}, (_, i) => Object.assign({}, point, {
            timestamp_ms: start + (i + 1) * bucket, duration_ms: bucket,
            cpu_percent_of_machine: i % 7, gpu_busy_percent: i % 5 * 3,
            memory_bytes: 78852915 + Math.floor(i / 5) * 200000,
            disk_read_bytes_per_second: i % 4 * 100, disk_write_bytes_per_second: i % 3 * 100,
            network_receive_bytes_per_second: i % 6 * 100, network_transmit_bytes_per_second: i % 4 * 100,
            average_power_watts: (i % 6 + 1) / 100,
            availability: Object.assign({}, point.availability, {network_bytes: true})
        }));
        const metric = {available: true, mean: 100, peak: 500, observed_ms: end - start, coverage: 1};
        c.resourceHistorySummary = Object.assign({}, c.resourceHistorySummary, {metrics: Object.assign({}, c.resourceHistorySummary.metrics, {
            network_receive_bytes_per_second: metric, network_transmit_bytes_per_second: metric
        })});
        panel.detailsItem.width = 680;
        wait(0);
        const chart = card(panel, "applicationResourceTimeline");
        verify(chart.wide);
        verify(panel.detailsItem.contentHeight < 760, "Default resource body is compact: " + panel.detailsItem.contentHeight);
        const memory = card(panel, "resourcePlot_memory");
        const activity = card(panel, "resourcePlot_activity");
        compare(memory.mapToItem(chart, 0, 0).x, activity.mapToItem(chart, 0, 0).x, "Shared time-axis alignment");
        compare(memory.width, activity.width);
        wait(20); // Canvas render smoke check; arithmetic/gap tests cover geometry.
        const pixels = grabImage(chart);
        verify(pixels.width > 0 && pixels.height > 0);
    }
    function test_responsiveGeometry_data() {
        return [{tag: "360", width: 360, scale: 1}, {tag: "540", width: 540, scale: 1},
            {tag: "680", width: 680, scale: 1}, {tag: "900", width: 900, scale: 1},
            {tag: "fractional", width: 680, scale: 1.25}];
    }
    function test_responsiveGeometry(data) {
        const panel = make();
        panel.detailsItem.width = data.width;
        panel.detailsItem.uiScale = data.scale;
        wait(20);
        const chart = card(panel, "applicationResourceTimeline");
        compare(chart.wide, data.width >= 480 * data.scale);
        for (const id of ["activity", "memory", "storage", "network", "energy"]) {
            const group = card(panel, "resourceGroup_" + id);
            const plot = card(panel, "resourcePlot_" + id);
            verify(group.width <= chart.width && group.height > 0);
            const position = plot.mapToItem(group, 0, 0);
            if (plot.visible) {
                verify(position.x >= 0 && position.x + plot.width <= group.width + 1);
                verify(position.y >= 0 && position.y + plot.height <= group.height + 1);
            }
        }
        keyClick(Qt.Key_Tab);
        compare(panel.detailsNavigation.availableFields().length, 1);
    }
    function test_narrowLayoutKeepsValuesAndChartStatisticsReadable() {
        const panel = make();
        panel.detailsItem.width = 350;
        wait(0);
        const page = panel.detailsItem;
        const chart = card(panel, "applicationResourceTimeline");
        verify(!chart.wide);
        verify(chart.height > 0);
        verify(page.contentHeight >= chart.height, "The complete timeline contributes to scroll geometry; compact content may fit");
        for (const name of ["applicationDiskFootprint", "applicationRam", "applicationGpuMemory", "applicationPeriodEnergy", "applicationIo_network_receive_bytes_per_second"]) {
            const control = card(panel, name);
            verify(control.width > 0 && control.width <= page.width);
            const value = findChild(control, "resourceValue");
            verify(!value.truncated, name + " has no elided resource value");
            verify(control.height >= control.implicitHeight - 1, name + " fits its wrapped content");
        }
    }
}
