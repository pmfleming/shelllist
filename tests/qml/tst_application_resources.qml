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
            id: surface
            property bool fullDetails: false
            property real resourceScale: 1
            width: tests.width
            height: tests.height
            chooserController: Apps.ApplicationController { id: controller }
            listComponent: Ui.ChooserListPane {
                chooserController: controller
                powerVisible: false
                resultModel: controller.filteredResultsModel
                rowDelegate: Rectangle { implicitWidth: 300; implicitHeight: 40 }
            }
            detailsComponent: fullDetails ? completeDetails : resourcesOnly
            Component {
                id: resourcesOnly
                Apps.ApplicationResourcesPage {
                    controller: controller
                    application: controller.selectedApplication || ({})
                    uiScale: surface.resourceScale
                }
            }
            Component {
                id: completeDetails
                Apps.ApplicationDetails {
                    controller: controller
                    uiScale: surface.resourceScale
                }
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
    function make(properties) {
        const panel = createTemporaryObject(factory, tests, properties || ({}));
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
        tryVerify(() => field(panel) !== null);
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
    function test_arrivingSnapshotsKeepDraftAndPartialFootprint() {
        const panel = make();
        const c = panel.chooserController;
        const before = historyCalls();
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Return);
        keyClick(Qt.Key_Right);
        compare(field(panel).displayedValue, "2h");
        const changed = fixture();
        changed.disk_space_permanent_bytes = null;
        changed.disk_read_bytes_per_second = null;
        changed.memory_bytes = 1024 * 1024 * 1024 * 123.4;
        c.replaceProviderResults([c.provider.resultFor(changed)], false);
        verify(panel.detailsNavigation.editing);
        compare(field(panel).displayedValue, "2h");
        compare(c.historyRange, "30m");
        compare(historyCalls(), before);
        verify(card(panel, "applicationDiskFootprint").available, "Valid footprint survives a missing component and read rate");
        verify(card(panel, "applicationDiskFootprint").detailText.includes("Persistent Unavailable. Temporary 97.7 KiB"));
        const read = card(panel, "resourceTotal_disk_read_bytes_per_second");
        verify(read.available, "Canonical period total survives an unavailable latest read rate");
        verify(read.detailText.includes("Current Unavailable"));
        verify(card(panel, "resourceTotal_disk_write_bytes_per_second").available);
        const receive = card(panel, "resourceTotal_network_receive_bytes_per_second");
        verify(!receive.available);
        compare(findChild(receive, "resourceValue").text, "—");
        verify(receive.Accessible.name.includes("Unavailable"));
        compare(card(panel, "applicationRam").valueText, "123 GiB", "Descriptor replacement updates the existing reading");
        keyClick(Qt.Key_Escape);
        compare(field(panel).displayedValue, "30m");
        compare(card(panel, "applicationResourceOverview").cards.length, 5);
    }
    function test_expandedMicrocardsFillViewport_data() {
        return [
            {tag: "expanded", w: 1040, h: 638, scale: 1},
            {tag: "short-dense", w: 1040, h: 540, scale: 0.82},
            {tag: "large", w: 1250, h: 900, scale: 1.12}
        ];
    }
    function test_expandedMicrocardsFillViewport(data) {
        width = data.w;
        height = data.h;
        const panel = make({fullDetails: true, resourceScale: data.scale});
        const page = card(panel, "applicationResourcesPage");
        const overview = card(panel, "applicationResourceOverview");
        tryVerify(() => overview.height > 100);
        wait(20);
        verify(page.contentHeight <= page.height + 1, "Page fits beneath the real header and above bottom tabs");
        verify(!page.interactive, "No scrollable resource content");
        const grid = card(panel, "applicationResourceCards");
        verify(Math.abs(grid.height - overview.height) < 1, "Grid fills all remaining height");
        for (const id of ["activity", "memory", "storage", "network", "energy"]) {
            const micro = card(panel, "resourceCard_" + id);
            const plot = card(panel, "resourcePlot_" + id);
            const point = micro.mapToItem(page, 0, 0);
            verify(point.y >= 0 && point.y + micro.height <= page.height + 1, id + " fits viewport");
            verify(plot.width > 25 && plot.height > 25, id + " keeps useful plot space");
            compare(plot.chartStyle, id === "energy" ? "columns" : "paired-columns");
            for (const reading of micro.readings) {
                const value = card(micro, reading.objectName);
                const position = value.mapToItem(micro, 0, 0);
                verify(position.y >= 0 && position.y + value.height <= micro.height + 1, id + " readings remain inside card");
            }
        }
        compare(panel.detailsNavigation.availableFields().length, 1);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_PageDown);
        compare(page.contentY, 0);
        const previous = card(panel, "resourceCard_activity").height;
        height += 100;
        tryVerify(() => card(panel, "resourceCard_activity").height > previous + 20, 5000, "Cards grow with the available viewport");
        verify(page.contentHeight <= page.height + 1);
    }
    function test_exceptionStatesStayVisibleWithoutScrolling() {
        width = 1040;
        height = 638;
        const panel = make({fullDetails: true});
        const c = panel.chooserController;
        const changed = fixture();
        changed.memory_swap_bytes = 1024 * 1024;
        changed.measurement.coverage = 0.5;
        changed.measurement.resources_shared = true;
        c.replaceProviderResults([c.provider.resultFor(changed)], false);
        const page = card(panel, "applicationResourcesPage");
        tryVerify(() => card(panel, "applicationSwapStatus").visible);
        verify(card(panel, "applicationProcessCoverage").visible);
        verify(card(panel, "applicationProcessCoverage").text.includes("Shared attribution"));
        verify(page.contentHeight <= page.height + 1);
        const energy = card(panel, "resourceCard_energy");
        verify(energy.mapToItem(page, 0, energy.height).y < page.height);
        const stopped = Object.assign({}, changed, {running: false});
        c.resourceHistory = [];
        c.replaceProviderResults([c.provider.resultFor(stopped)], false);
        tryVerify(() => card(panel, "applicationResourceSnapshotStatus").visible);
        verify(card(panel, "applicationResourceSnapshotStatus").text.includes("no retained measurements"));
        verify(!card(panel, "applicationCpuActivity").available);
        verify(card(panel, "resourceContentState_activity").visible);
        verify(page.contentHeight <= page.height + 1);
    }
    function test_pairedBarsKeepZerosAndIndependentGaps() {
        const panel = make();
        const c = panel.chooserController;
        const start = c.historyWindowStartMs;
        const duration = (c.historyWindowEndMs - start) / 3;
        c.resourceHistory = [
            {timestamp_ms: start + duration, duration_ms: duration, cpu_percent_of_machine: 0, gpu_busy_percent: 20, availability: {cpu: true, gpu: true}},
            {timestamp_ms: start + duration * 2, duration_ms: duration, cpu_percent_of_machine: 10, gpu_busy_percent: null, availability: {cpu: true, gpu: true}},
            {timestamp_ms: start + duration * 3, duration_ms: duration, cpu_percent_of_machine: 20, gpu_busy_percent: 30, availability: {cpu: true, gpu: true}}
        ];
        const plot = card(panel, "resourcePlot_activity");
        compare(plot.segments[0].length, 1);
        compare(plot.segments[1].length, 2, "Missing GPU sample must not bridge the gap");
        compare(plot.columnRect(plot.segments[0][0][0], 0).height, 0, "Measured zero has no artificial bar");
        const cpu = plot.columnRect(plot.segments[0][0][0], 0);
        const gpu = plot.columnRect(plot.segments[1][0][0], 1);
        verify(cpu.x + cpu.width < gpu.x, "Paired columns are adjacent, not stacked");
        verify(gpu.x + gpu.width <= plot.xFor(start + duration), "Columns stay within their observed bucket");
    }
    function test_loadingTotalsAndPairedHistory() {
        const panel = make();
        const c = panel.chooserController;
        const activity = card(panel, "resourcePlot_activity");
        compare(activity.series.length, 2, "CPU/GPU share one plot without summing");
        compare(activity.maximum, 100);
        compare(card(panel, "resourcePlot_memory").series.length, 2);
        verify(card(panel, "resourceTotal_average_power_watts").available);
        verify(card(panel, "resourceTotal_disk_read_bytes_per_second").valueText.startsWith("≈ "));
        const range = field(panel);
        const before = historyCalls();
        mouseClick(range, range.width / 2, range.height / 2);
        compare(c.historyRange, "30m", "Pointer choice is still a local draft");
        compare(historyCalls(), before);
        keyClick(Qt.Key_Return);
        compare(c.historyRange, "2h");
        verify(!card(panel, "resourceTotal_disk_read_bytes_per_second").available);
        verify(!activity.visible, "Never show old-window bars while loading");
        verify(card(panel, "applicationRam").available, "Current readings survive range loading");
        verify(card(panel, "resourceContentState_activity").visible);
        seedHistory(c);
        tryVerify(() => activity.visible);
        verify(card(panel, "resourceTotal_disk_read_bytes_per_second").available);
        verify(card(panel, "applicationDiskFootprint").available);
        compare(panel.detailsNavigation.availableFields().length, 1);
    }
}
