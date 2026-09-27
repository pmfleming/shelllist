import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    name: "ResultStore"

    function result(id, title, score) {
        return {
            providerId: "test",
            id: id,
            title: title,
            score: score,
            actions: []
        };
    }

    function init() {
        store.clear();
        store.queryText = "";
        staleSpy.clear();
    }

    function test_handlesAsynchronousRankingBoundaries() {
        store.activeQueryId = "query-current";
        verify(!store.applyBatch({
            providerId: "test",
            queryId: "query-old",
            replace: true,
            complete: true,
            results: [result("stale", "Stale", 1)]
        }));
        compare(staleSpy.count, 1);
        compare(store.count, 0);

        store.replaceProviderResults("test", [result("first", "First", 20), result("second", "Second", 10)], true);
        store.queryText = "no-synchronous-match";
        compare(store.count, 2);

        store.applyRustRanking(store.searchOwner, store.searchGeneration, ["test::second"]);
        compare(store.count, 1);
        compare(store.visibleModel.get(0).resultData.id, "second");
    }

    function test_providerProjectionOwnsIdentityWithoutMutatingPayload() {
        const payload = {
            id: "one",
            title: "One",
            providerId: "wrong",
            providerPriority: 999
        };
        const normalized = testProvider.makeResult(payload);
        compare(normalized.providerId, "test");
        compare(normalized.providerPriority, 7);
        compare(payload.providerId, "wrong");
        compare(payload.providerPriority, 999);
        const projected = testProvider.resultsFor([payload,
            {
                id: "two",
                title: "Two"
            }
        ]);
        compare(projected.length, 2);
        compare(projected[0].key, "test::one");
        compare(projected[0].title, "Projected One");
        compare(projected[1].key, "test::two");
        compare(testProvider.resultsFor(null).length, 0);
    }

    Core.ProviderRegistry {
        id: providerRegistry
        Core.Provider {
            id: testProvider
            providerId: "test"
            displayName: "Test"
            priority: 7
            function resultFor(payload: var): var {
                return makeResult({
                    id: payload.id,
                    title: "Projected " + payload.title
                });
            }
        }
    }
    Core.ResultStore {
        id: store
        registry: providerRegistry
        rankRequestsEnabled: false
    }
    SignalSpy {
        id: staleSpy
        target: store
        signalName: "staleBatchIgnored"
    }
}
