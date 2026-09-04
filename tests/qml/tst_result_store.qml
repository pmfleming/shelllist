import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    name: "ResultStore"

    function result(id, title, score) {
        return { providerId: "test", id: id, title: title, score: score, actions: [] };
    }

    function init() {
        store.clear();
        store.queryText = "";
        staleSpy.clear();
    }

    function test_synchronizesRankingAndSelection() {
        store.replaceProviderResults("test", [
            result("low", "Low", 10),
            result("high", "High", 30),
            result("mid", "Middle", 20)
        ], true);
        tryCompare(store, "count", 3);
        compare(store.visibleModel.get(0).resultData.id, "high");

        store.selectedIndex = 1;
        compare(store.selected().id, "mid");
        store.replaceProviderResults("test", [
            result("high", "High", 5), result("mid", "Middle", 40)
        ], false);
        compare(store.selected().id, "mid");
        compare(store.selectedIndex, 0);
    }

    function test_retainsSelectionAcrossSameQueryRefresh() {
        store.replaceProviderResults("test", [
            result("first", "First", 20), result("second", "Second", 10)
        ], true);
        store.selectedIndex = 1;

        const request = store.beginQuery("", {}, ["test"], 50);
        compare(store.selected().id, "second");

        verify(store.applyBatch({
            providerId: "test", queryId: request.id, replace: true,
            complete: true, results: [
                result("first", "First", 5), result("second", "Second", 40)
            ]
        }));
        compare(store.selected().id, "second");
        compare(store.selectedIndex, 0);
    }

    function test_handlesAsynchronousRankingBoundaries() {
        store.activeQueryId = "query-current";
        verify(!store.applyBatch({
            providerId: "test", queryId: "query-old", replace: true,
            complete: true, results: [result("stale", "Stale", 1)]
        }));
        compare(staleSpy.count, 1);
        compare(store.count, 0);

        store.replaceProviderResults("test", [
            result("first", "First", 20), result("second", "Second", 10)
        ], true);
        store.queryText = "no-synchronous-match";
        compare(store.count, 2);

        store.applyRustRanking(store.searchOwner, store.searchGeneration, ["test::second"]);
        compare(store.count, 1);
        compare(store.visibleModel.get(0).resultData.id, "second");
    }

    function test_largeCatalogIsPopulatedProgressively() {
        const values = [];
        for (let index = 0; index < 1000; index++)
            values.push(result("large-" + index, "Large " + index, 1000 - index));

        store.replaceProviderResults("test", values, true);

        compare(store.count, 1000);
        verify(store.lastCatalogToModelLatencyMs >= 0);
        verify(store.visibleModel.count > 0);
        verify(store.visibleModel.count < 1000);
        tryCompare(store.visibleModel, "count", 1000);
        compare(store.visibleModel.get(999).resultData.id, "large-999");
    }

    Core.ProviderRegistry {
        id: providerRegistry
        Core.Provider { providerId: "test"; displayName: "Test" }
    }
    Core.ResultStore {
        id: store
        registry: providerRegistry
        rankRequestsEnabled: false
    }
    SignalSpy { id: staleSpy; target: store; signalName: "staleBatchIgnored" }
}
