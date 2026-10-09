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
        verify(overview.height > 100);
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
            const inset = Math.round(4 * data.scale);
            compare(plot.parent, micro, "Plot is a card background, not a separate layout column");
            compare(plot.x, inset);
            compare(plot.y, inset);
            compare(plot.width, micro.width - 2 * inset);
            compare(plot.height, micro.height - 2 * inset);
            const overlay = card(micro, "resourceOverlay_" + id);
            verify(overlay.z > plot.z, "Readings paint above the full-card graph");
            compare(overlay.y, micro.inset, "All card readings start at the top inset");
            verify(overlay.y + overlay.height <= micro.height - micro.inset + 1, "Readable rows stay inside the card");
            compare(micro.readings.length, 2);
            compare(micro.valueSize, card(panel, "resourceCard_activity").valueSize, "One value scale across every card");
            verify(micro.glyphSize >= Ui.Theme.formValueSize);
            compare(plot.chartStyle, id === "energy" ? "columns" : "paired-columns");
            for (const reading of micro.readings) {
                const value = card(micro, reading.objectName);
                const position = value.mapToItem(micro, 0, 0);
                verify(position.y >= micro.inset && position.y + value.height <= micro.height - micro.inset + 1, id + " readings remain inside the card");
                verify(value.fitToSlot);
                compare(value.valueSize, micro.valueSize, "Every reading uses the card's responsive typography");
                compare(card(value, "resourceGlyph").height, micro.glyphSize);
                verify(position.x < micro.width / 3, id + " readings stay on the left");
                verify(position.x >= plot.x && position.x < plot.x + plot.width, "Graph continues beneath the values");
                verify(value.overChart, "Outline keeps values readable over bars");
            }
        }
        const powerCard = card(panel, "resourceCard_energy");
        compare(findChild(powerCard, "applicationDiskFootprint"), null);
        compare(powerCard.readings.length, 2, "Power and energy only");
        compare(card(powerCard, "resourceTotal_average_power_watts").glyph, "∑", "Energy uses a real sigma, never a literal icon name");
        compare(panel.detailsNavigation.availableFields().length, 1);
        keyClick(Qt.Key_Tab);
        keyClick(Qt.Key_PageDown);
        compare(page.contentY, 0);
        const previous = card(panel, "resourceCard_activity").height;
        const sizes = ["activity", "memory", "storage", "network", "energy"].map(id => card(panel, "resourceCard_" + id).valueSize);
        height += 100;
        verify(waitForPolish(panel.Window.window));
        verify(card(panel, "resourceCard_activity").height > previous + 20, "Cards grow with the available viewport");
        verify(page.contentHeight <= page.height + 1);
        ["activity", "memory", "storage", "network", "energy"].forEach((id, index) => {
            verify(card(panel, "resourceCard_" + id).valueSize >= sizes[index], id + " typography grows to its shared ceiling");
        });
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
        verify(waitForPolish(panel.Window.window));
        const page = card(panel, "applicationResourcesPage");
        tryVerify(() => card(panel, "applicationSwapStatus").active);
        verify(card(panel, "applicationProcessCoverage").active);
        verify(card(panel, "applicationProcessCoverage").text.includes("Shared attribution"));
        verify(page.contentHeight <= page.height + 1);
        const energy = card(panel, "resourceCard_energy");
        verify(energy.mapToItem(page, 0, energy.height).y < page.height);
        const stopped = Object.assign({}, changed, {running: false});
        c.resourceHistory = [];
        c.replaceProviderResults([c.provider.resultFor(stopped)], false);
        verify(waitForPolish(panel.Window.window));
        tryVerify(() => card(panel, "applicationResourceSnapshotStatus").active);
        verify(card(panel, "applicationResourceSnapshotStatus").text.includes("no retained measurements"));
        verify(!card(panel, "applicationCpuActivity").available);
        verify(card(panel, "resourceContentState_activity").visible);
        verify(page.contentHeight <= page.height + 1);
    }
    function test_observationCoverageIsAccessibleWithoutFooters() {
        const panel = make();
        const storage = card(panel, "resourceCard_storage");
        verify(storage.lane.coverageText.includes("15m/30m"), "Fixture has partial disk coverage");
        verify(storage.Accessible.name.includes("15m/30m"), "Coverage remains accessible");
        for (const id of ["activity", "memory", "storage", "network", "energy"]) {
            compare(findChild(panel, "resourceCoverage_" + id), null, "No observation footer");
            const status = card(panel, "resourceStatus_" + id);
            compare(status.text.length > 0, id === "network", "Only an actual unavailable reading needs visible status");
            verify(!status.text.includes("30m"));
        }
        compare(card(panel, "resourceStatus_network").text, "Unavailable");
    }
    function test_pairedBarsKeepZerosAndIndependentGaps() {
        const panel = make();
        const c = panel.chooserController;
        const start = c.historyWindowStartMs;
        const duration = Math.floor((c.historyWindowEndMs - start) / 3);
        c.resourceHistory = [
            {timestamp_ms: start + duration, duration_ms: duration, cpu_percent_of_machine: 0, gpu_busy_percent: 20, metric_availability: {cpu_percent_of_machine: true, gpu_busy_percent: true}},
            {timestamp_ms: start + duration * 2, duration_ms: duration, cpu_percent_of_machine: 10, gpu_busy_percent: null, metric_availability: {cpu_percent_of_machine: true, gpu_busy_percent: true}},
            {timestamp_ms: start + duration * 3, duration_ms: duration, cpu_percent_of_machine: 20, gpu_busy_percent: 30, metric_availability: {cpu_percent_of_machine: true, gpu_busy_percent: true}}
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
    function test_missingIntervalsHaveNoDashedPaint() {
        const panel = make();
        for (const id of ["activity", "energy"]) {
            const plot = card(panel, "resourcePlot_" + id);
            card(panel, "resourceOverlay_" + id).visible = false;
            tryVerify(() => plot.available && plot.visible);
            plot.requestPaint();
            wait(30);
            const pixels = grabImage(panel);
            const origin = plot.mapToItem(panel, 0, 0);
            // The fixture has only a retained bucket near the right edge. All
            // earlier missing time must be blank, without full-height hatching
            // or the old bottom coverage-band dashes. Horizontal guides may stay.
            for (const fraction of [0.25, 0.7, 0.94]) {
                const y = Math.floor(origin.y + plot.height * fraction);
                const left = Math.floor(origin.x) + Math.max(24, Math.floor(plot.width * 0.1));
                const blank = pixels.pixel(left, y);
                for (let x = left + 1; x < Math.floor(origin.x + plot.width * 0.8); ++x)
                    compare(pixels.pixel(x, y), blank, id + " missing intervals have no vertical pattern");
            }
        }
    }
    function test_loadingTotalsAndPairedHistory() {
        const panel = make();
        const c = panel.chooserController;
        const activity = card(panel, "resourcePlot_activity");
        compare(activity.series.length, 2, "CPU/GPU share one plot without summing");
        compare(activity.maximum, 100);
        compare(card(panel, "resourcePlot_memory").series.length, 2);
        verify(card(panel, "resourceTotal_average_power_watts").available);
        verify(!card(panel, "resourceTotal_disk_read_bytes_per_second").valueText.includes("≈"));
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
        compare(findChild(panel, "applicationDiskFootprint"), null);
        compare(panel.detailsNavigation.availableFields().length, 1);
    }
}
