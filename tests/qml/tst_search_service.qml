import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    name: "SearchServiceOwnership"
    function test_emptyQueriesDebouncePerOwnerAndRetireWithoutReplay() {
        const first = Core.SearchService.allocateOwner();
        const second = Core.SearchService.allocateOwner();
        Core.SearchService.updateCatalog(first, [{key: "a", title: "Alpha", score: 0.25}]);
        Core.SearchService.updateCatalog(second, []);
        Core.SearchService.rank(first, 1, "alpha");
        Core.SearchService.rank(second, 3, "beta");
        Core.SearchService.rank(first, 2, "");
        const pending = Core.SearchService.queuedRequests.filter(request => request.owner === first);
        compare(pending.length, 1);
        compare(pending[0].query, "");
        compare(pending[0].generation, 2);
        compare(Core.SearchService.latestRequests[first].query, "", "reconnect must replay empty queries too");
        compare(Core.SearchService.catalogs[first][0].score, 0.25);
        Core.SearchService.releaseOwner(first);
        verify(Core.SearchService.catalogs[first] === undefined);
        verify(Core.SearchService.latestRequests[first] === undefined);
        verify(!Core.SearchService.queuedRequests.some(request => request.owner === first));
        compare(Core.SearchService.latestRequests[second].query, "beta");
        Core.SearchService.releaseOwner(second);
    }
}
