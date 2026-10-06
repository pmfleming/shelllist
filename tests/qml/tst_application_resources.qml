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
    function init() { failOnWarning(/.*/); calls = []; }
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
        verify(card(panel, "applicationDiskFootprint").label.indexOf("not the complete installation") >= 0);
        verify(card(panel, "applicationDiskFootprint").detailText.indexOf("Temporary:") >= 0);
        verify(card(panel, "applicationReferencedFiles").text.indexOf("not added") >= 0);
        const disk = card(panel, "applicationIo_disk_read_bytes_per_second");
        compare(disk.valueText, "0 B/s");
        verify(disk.available);
        verify(disk.detailText.indexOf("15.0 min observed / 30.0 min") >= 0);
        const network = card(panel, "applicationIo_network_receive_bytes_per_second");
        verify(!network.available);
        compare(findChild(network, "resourceValue").text, "—");
        verify(network.detailText.indexOf("unavailable; not zero") >= 0);
        const chart = card(panel, "applicationResourceTimeline");
        verify(chart.lanes[0].valueText.indexOf("0.0%") >= 0);
        verify(chart.lanes[4].unavailable);
        verify(chart.timeLabel(4) !== "Now", "Retained window ends are timestamps, never fake live samples");
    }
    function test_retainedAndMissingMetricStates() {
        const panel = make();
        const c = panel.chooserController;
        const stopped = Object.assign(fixture(), {running: false});
        c.replaceProviderResults([c.provider.resultFor(stopped)], false);
        tryVerify(() => card(panel, "applicationResourceSnapshotStatus").text.indexOf("App stopped") >= 0);
        verify(card(panel, "applicationPower").label.indexOf("Last observed") >= 0);
        verify(card(panel, "applicationRam").detailText.indexOf("NOT RECORDED") >= 0, "Historical samples do not carry a PSS/RSS source");
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
    function test_narrowLayoutKeepsValuesAndChartStatisticsReadable() {
        const panel = make();
        panel.detailsItem.width = 350;
        wait(0);
        const page = panel.detailsItem;
        const chart = card(panel, "applicationResourceTimeline");
        verify(!chart.wide);
        verify(chart.height > 0);
        verify(page.contentHeight > page.height);
        for (const name of ["applicationDiskFootprint", "applicationRam", "applicationGpuMemory", "applicationPeriodEnergy", "applicationIo_network_receive_bytes_per_second"]) {
            const control = card(panel, name);
            verify(control.width > 0 && control.width <= page.width);
            const value = findChild(control, "resourceValue");
            verify(!value.truncated, name + " has no elided resource value");
            verify(control.height >= control.implicitHeight - 1, name + " fits its wrapped content");
        }
    }
}
