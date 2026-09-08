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
