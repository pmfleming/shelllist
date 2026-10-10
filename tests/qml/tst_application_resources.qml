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
            metric_availability: {cpu_percent_of_machine: true, memory_bytes: true, memory_swap_bytes: true,
                gpu_busy_percent: true, gpu_memory_resident_bytes: true, gpu_memory_allocated_bytes: true,
                disk_space_total_bytes: true, disk_space_permanent_bytes: true, disk_space_temporary_bytes: true,
                referenced_file_disk_bytes: true, referenced_file_temporary_bytes: true,
                disk_read_bytes_per_second: true, disk_write_bytes_per_second: true, average_power_watts: true},
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
        // Finding a child is not proof that the asynchronous page Loader has
        // completed. Wait for construction, expansion and layout before using
        // any resource-card geometry or delivering pointer input.
        const page = card(panel, "applicationResourcesPage");
        tryCompare(page.parent, "status", Loader.Ready);
        tryCompare(controller, "detailsExpansionProgress", 1);
        verify(waitForPolish(panel.Window.window));
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
            disk_read_bytes_per_second: Object.assign({}, metric, {mean: 100, peak: 400, observed_ms: (end - start) / 2, observed_total: 100 * (end - start) / 2000, total_unit: "bytes"}),
            disk_write_bytes_per_second: Object.assign({}, metric, {observed_total: 0, total_unit: "bytes"}),
            average_power_watts: Object.assign({}, metric, {mean: 0.01, peak: 0.38, observed_total: 0.01 * (end - start) / 3600, total_unit: "mWh"})
        };
        const point = Object.assign(fixture(), {timestamp_ms: end - 15000, duration_ms: 15000,
            average_power_watts: 0.01, coverage: 1, sample_count: 7,
            availability: {cpu: true, memory: true, gpu: true, energy: true, disk_space: true, referenced_files: true, storage: true, network_bytes: false}});
        controller.applyResourceHistory(controller.activeHistoryRequestId, {
            target_id: controller.selectedResult.id, points: [point], has_more: false, next_cursor: "fixture",
            summary: {energy_confidence: "low", window_start_ms: start, window_end_ms: end, revision: "fixture", weighting: "observed-duration", metrics: metrics}
        });
    }
    function field(panel) { return findChild(panel, "applicationHistoryRange"); }
    function card(panel, name) {
        // Nested Repeater delegates can still be incubating after their parent
        // status is visible, especially in the offscreen build sandbox.
        tryVerify(() => findChild(panel, name) !== null, 5000, name);
        return findChild(panel, name);
    }
    function test_appDataIsPassiveApplicationContext() {
        const panel = make({fullDetails: true});
        const c = panel.chooserController;
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_Tab, Qt.ControlModifier | Qt.ShiftModifier);
        tryCompare(c, "detailsTab", "application");
        const data = card(panel, "applicationDataDetails");
        compare(data.entries[0].value, "6.1 MiB");
        const changed = fixture();
        changed.disk_space_permanent_bytes = null;
        changed.disk_space_total_bytes = 0;
        c.replaceProviderResults([c.provider.resultFor(changed)], false);
        compare(data.entries[0].value, "0 B", "Measured zero remains valid app data");
        compare(data.entries[1].value, "Unavailable", "A missing component is not zero");
        compare(data.entries[2].value, "97.7 KiB");
        compare(panel.detailsNavigation.availableFields().length, 0, "App data adds no editable stop");
        const stopped = Object.assign(fixture(), {running: false});
        const other = Object.assign(fixture(), {id: "other-app", running: false});
        c.replaceProviderResults([c.provider.resultFor(stopped), c.provider.resultFor(other)], false);
        compare(data.entries[0].value, "6.1 MiB", "Stopped app uses its own retained observation");
        const before = historyCalls();
        tryCompare(panel.listItem, "resultCount", 2);
        verify(waitForPolish(panel.Window.window));
        panel.listItem.focusList();
        tryVerify(() => panel.listItem.listFocused);
        keyClick(panel.listItem.selectedIndex === 0 ? Qt.Key_Down : Qt.Key_Up);
        tryVerify(() => c.selectedApplication.id === "other-app");
        compare(card(panel, "applicationDataDetails").entries[0].value, "Unavailable", "Never borrow another application's history");
        compare(historyCalls(), before, "Passive metadata does not query history");
    }
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
        verify(!card(panel, "resourcePlot_activity").visible, "Never show old-window bars while loading");
        verify(card(panel, "applicationRam").available, "Current readings survive range loading");
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
        compare(findChild(panel, "applicationDiskFootprint"), null, "Storage attribution is not a power reading");
        const read = card(panel, "resourceTotal_disk_read_bytes_per_second");
        verify(read.available, "Canonical period total survives an unavailable latest read rate");
        verify(read.detailText.includes("Current Unavailable"));
        verify(read.Accessible.name.includes("Estimated"), "Removing a visible approximation sign does not erase estimation semantics");
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
}
