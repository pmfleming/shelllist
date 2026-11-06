pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    id: tests
    name: "SearchServiceOwnership"
    property var originalFactory
    property var replies: []
    Component {
        id: fakeBackend
        QtObject {
            property bool ready: true
            property var calls: []
            signal transportReady
            signal transportFailed(string message, var lostRequestIds)
            signal responseReceived(string id, var envelope, string error)
            signal sendFailed(string id, string message)
            function call(id, method, params) { calls = calls.concat([{id:id, method:method, params:params}]); return true; }
            function responseError(envelope, transportError, fallback) { return transportError || (envelope?.ok ? "" : fallback); }
        }
    }
    Connections {
        target: Core.SearchService
        function onRanked(owner: string, generation: int, keys: var): void {
            tests.replies = tests.replies.concat([{owner:owner, generation:generation, keys:keys}]);
        }
    }
    function init() {
        Core.SearchService.transportActive = false;
        originalFactory = Core.SearchService.backendFactory;
        Core.SearchService.backendFactory = fakeBackend;
        replies = [];
    }
    function cleanup() {
        Object.keys(Core.SearchService.catalogs).forEach(owner => Core.SearchService.releaseOwner(owner));
        Core.SearchService.transportActive = false;
        Core.SearchService.resetTransport();
        Core.SearchService.backendFactory = originalFactory;
    }
    function ack(index, data) {
        const backend = Core.SearchService.backend;
        backend.responseReceived(backend.calls[index].id, {ok:true, protocol:"bar-api", version:2, data:data}, "");
    }
    function test_emptyQueriesDebouncePerOwnerAndRetireWithoutReplay() {
        const first = Core.SearchService.allocateOwner();
        const second = Core.SearchService.allocateOwner();
        Core.SearchService.updateCatalog(first, [{key:"a", title:"Alpha", score:0.25}]);
        Core.SearchService.updateCatalog(second, []);
        Core.SearchService.rank(first, 1, "alpha");
        Core.SearchService.rank(second, 3, "beta");
        Core.SearchService.rank(first, 2, "");
        const pending = Core.SearchService.queuedRequests.filter(request => request.owner === first);
        compare(pending.length, 1);
        compare(pending[0].query, "");
        compare(pending[0].generation, 2);
        compare(Core.SearchService.latestRequests[first].query, "");
        compare(Core.SearchService.catalogs[first][0].score, 0.25);
        Core.SearchService.releaseOwner(first);
        verify(Core.SearchService.catalogs[first] === undefined);
        verify(Core.SearchService.latestRequests[first] === undefined);
        verify(!Core.SearchService.queuedRequests.some(request => request.owner === first));
        compare(Core.SearchService.latestRequests[second].query, "beta");
    }
    function test_catalogAckFencesQueriesAndStaleRepliesAndReconnectReplaysOnlyLiveOwners() {
        const owner = Core.SearchService.allocateOwner();
        Core.SearchService.updateCatalog(owner, [{key:"a", title:"Alpha"}]);
        Core.SearchService.rank(owner, 1, "a");
        const backend = Core.SearchService.backend;
        tryVerify(() => backend.calls.length === 1);
        compare(backend.calls[0].method, "search.catalog");
        ack(0, {owner:owner, revision:1});
        tryVerify(() => backend.calls.length === 2);
        compare(backend.calls[1].method, "search.query");
        Core.SearchService.updateCatalog(owner, [{key:"b", title:"Beta"}]);
        Core.SearchService.rank(owner, 2, "");
        ack(1, {owner:owner, revision:1, generation:1, keys:["a"]});
        compare(replies.length, 0);
        tryVerify(() => backend.calls.length === 3);
        compare(backend.calls[2].params.revision, 2);
        ack(2, {owner:owner, revision:2});
        tryVerify(() => backend.calls.length === 4);
        ack(3, {owner:owner, revision:2, generation:2, keys:["b"]});
        compare(replies.length, 1);
        compare(replies[0].keys, ["b"]);
        backend.ready = false;
        backend.transportFailed("gone", []);
        backend.ready = true;
        backend.transportReady();
        tryVerify(() => backend.calls.length === 5);
        compare(backend.calls[4].method, "search.catalog");
        Core.SearchService.releaseOwner(owner);
        compare(backend.calls.length, 5, "release waits for its in-flight catalog acknowledgement");
        ack(4, {owner:owner, revision:2});
        compare(backend.calls[5].method, "search.release");
        ack(5, {owner:owner});
        backend.transportReady();
        compare(backend.calls.length, 6, "released owner is never restored");
    }
}
