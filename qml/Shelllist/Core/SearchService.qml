pragma Singleton

import QtQuick
import Shelllist.Io as Io

Item {
    id: service

    property int ownerSequence: 0
    property int requestSequence: 0
    property var queuedRequests: []
    property var catalogs: ({})
    property var revisions: ({})
    property var acceptedRevisions: ({})
    property var latestRequests: ({})
    property var inFlight: ({})
    property var busyOwners: ({})
    property var pendingReleases: ({})
    property bool transportActive: false
    property int rankDebounceMs: 35
    readonly property var backend: backendLoader.item
    readonly property bool ready: backend?.ready ?? false

    signal ranked(string owner, int generation, var keys)

    function allocateOwner(): string {
        ownerSequence += 1;
        return "result-store-" + ownerSequence;
    }

    function releaseOwner(owner: string): void {
        const nextCatalogs = Object.assign({}, catalogs);
        const nextRequests = Object.assign({}, latestRequests);
        delete nextCatalogs[owner];
        delete nextRequests[owner];
        catalogs = nextCatalogs;
        latestRequests = nextRequests;
        delete acceptedRevisions[owner];
        queuedRequests = queuedRequests.filter(request => request.owner !== owner);
        if (ready) {
            if (busyOwners[owner])
                pendingReleases[owner] = true;
            else
                send("search.release", {owner: owner});
        }
    }

    function compactItems(items: var): var {
        return (items || []).map(function (item) {
            return {
                key: item.key,
                title: item.title,
                subtitle: item.subtitle,
                keywords: item.keywords || [],
                score: item.score || 0,
                providerPriority: item.providerPriority || 0
            };
        });
    }

    function updateCatalog(owner: string, items: var): void {
        catalogs = Object.assign({}, catalogs, {[owner]: compactItems(items)});
        revisions = Object.assign({}, revisions, {[owner]: (revisions[owner] || 0) + 1});
    }

    function rank(owner: string, generation: int, query: string): void {
        const request = {owner: owner, generation: generation, query: query || ""};
        latestRequests = Object.assign({}, latestRequests, {[owner]: request});
        queue(request);
        rankDebounce.restart();
        transportActive = true;
    }

    function queue(request: var): void {
        queuedRequests = queuedRequests.filter(queued => queued.owner !== request.owner).concat([request]);
    }

    function send(method: string, params: var): void {
        const id = "search-" + (++requestSequence);
        inFlight[id] = {method: method, params: params};
        busyOwners[params.owner] = id;
        backend.call(id, method, params);
    }

    function flush(): void {
        if (!ready)
            return;
        const requests = queuedRequests;
        queuedRequests = [];
        requests.forEach(function (request) {
            const owner = request.owner;
            if (catalogs[owner] === undefined || latestRequests[owner] !== request)
                return;
            if (busyOwners[owner]) {
                queue(request);
                return;
            }
            if (acceptedRevisions[owner] !== revisions[owner]) {
                queue(request);
                send("search.catalog", {owner: owner, revision: revisions[owner], items: catalogs[owner]});
            } else {
                send("search.query", Object.assign({}, request, {revision: revisions[owner]}));
            }
        });
    }

    function completed(id: string, envelope: var, transportError: string): void {
        const request = inFlight[id];
        if (!request)
            return;
        delete inFlight[id];
        const params = request.params;
        const owner = params.owner;
        if (busyOwners[owner] === id)
            delete busyOwners[owner];
        if (pendingReleases[owner]) {
            delete pendingReleases[owner];
            send("search.release", {owner: owner});
            return;
        }
        if (request.method === "search.release") {
            if (!rankDebounce.running)
                flush();
            return;
        }
        if (catalogs[owner] === undefined)
            return;
        const error = backend.responseError(envelope, transportError, "Search failed");
        if (error) {
            // Busy reads may retry; transport recovery replays only live catalogs
            // and their latest query. Invalid input never loops on a timer.
            if (envelope?.error?.code === "busy") {
                queue(latestRequests[owner]);
                retryTimer.restart();
            } else if (envelope?.error?.code === "catalog-not-found" || envelope?.error?.code === "stale-catalog") {
                delete acceptedRevisions[owner];
                queue(latestRequests[owner]);
                retryTimer.restart();
            } else if (!transportError) {
                console.warn("shelllist search: " + error);
            }
            return;
        }
        const data = envelope.data || ({});
        if (data.owner !== owner || data.revision !== params.revision)
            return;
        if (request.method === "search.catalog") {
            acceptedRevisions[owner] = params.revision;
        } else if (params.revision === revisions[owner]
                && params.generation === latestRequests[owner]?.generation
                && data.generation === params.generation && Array.isArray(data.keys)) {
            ranked(owner, data.generation, data.keys);
        }
        if (!rankDebounce.running)
            flush();
    }

    function resetTransport(): void {
        acceptedRevisions = ({});
        inFlight = ({});
        busyOwners = ({});
        pendingReleases = ({});
        queuedRequests = Object.values(latestRequests);
    }

    property Component backendFactory: Component {
        Io.DaemonBackend {
            daemonName: "bar-daemon"
            expectedProtocol: "bar-api"
            expectedVersion: 2
            active: true
            streams: []
        }
    }
    Loader {
        id: backendLoader
        active: service.transportActive
        sourceComponent: service.backendFactory
        onLoaded: if (service.ready) {
            service.resetTransport();
            if (!rankDebounce.running)
                service.flush();
        }
    }
    Connections {
        target: service.backend
        function onTransportReady(): void {
            service.resetTransport();
            if (!rankDebounce.running)
                service.flush();
        }
        function onTransportFailed(): void { service.resetTransport(); }
        function onResponseReceived(id: string, envelope: var, error: string): void { service.completed(id, envelope, error); }
        function onSendFailed(id: string, message: string): void { service.completed(id, null, message); }
    }

    Timer {
        id: rankDebounce
        interval: service.rankDebounceMs
        onTriggered: service.flush()
    }
    Timer {
        id: retryTimer
        interval: 100
        onTriggered: service.flush()
    }
}
