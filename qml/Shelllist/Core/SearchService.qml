pragma Singleton

import QtQuick

Item {
    id: service

    property int ownerSequence: 0
    property var queuedRequests: []
    property var catalogs: ({})
    property int rankDebounceMs: 35
    // Loader.item is dynamically resolved as SearchProcess.qml at runtime.
    // qmllint disable missing-property
    readonly property bool ready: processLoader.item
        ? !!processLoader.item["ready"] : false
    // qmllint enable missing-property

    signal ranked(string owner, int generation, var keys)

    function allocateOwner(): string {
        ownerSequence += 1;
        return "result-store-" + ownerSequence;
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

    function writeMessage(message: var): void {
        if (!processLoader.item)
            return;
        // qmllint disable missing-property
        processLoader.item["write"](JSON.stringify(message) + "\n");
        // qmllint enable missing-property
    }

    function updateCatalog(owner: string, items: var): void {
        const next = Object.assign({}, catalogs);
        next[owner] = compactItems(items);
        catalogs = next;
        if (ready)
            writeMessage({ type: "catalog", owner: owner, items: next[owner] });
    }

    function sendCatalogs(): void {
        Object.keys(catalogs).forEach(function (owner) {
            writeMessage({ type: "catalog", owner: owner, items: catalogs[owner] });
        });
    }

    function rank(owner: string, generation: int, query: string): void {
        const request = {
            type: "query",
            owner: owner,
            generation: generation,
            query: query || ""
        };
        // Keep only the latest query per owner during the typing debounce. The
        // Rust worker also coalesces commands received behind in-flight work.
        queuedRequests = queuedRequests.filter(function (queued) {
            return queued.owner !== owner;
        }).concat([request]);
        rankDebounce.restart();
        if (!processLoader.active)
            processLoader.active = true;
        else if (!ready)
            start();
    }

    function start(): void {
        // qmllint disable missing-property
        if (!processLoader.item || processLoader.item["running"] || restartTimer.running)
            return;
        try {
            processLoader.item["start"]();
        } catch (error) {
            console.error("shelllist fuzzy search failed to start: " + error);
            restartTimer.restart();
        }
        // qmllint enable missing-property
    }

    function flush(): void {
        if (!processLoader.item)
            return;
        const requests = queuedRequests;
        queuedRequests = [];
        for (let index = 0; index < requests.length; index++)
            writeMessage(requests[index]);
    }

    function handleLine(line: string): void {
        try {
            const response = JSON.parse(line);
            if (response.error) {
                console.warn("shelllist fuzzy search rejected a request: " + response.error);
                return;
            }
            ranked(response.owner || "", Number(response.generation) || 0,
                response.keys || []);
        } catch (error) {
            console.warn("shelllist fuzzy search returned invalid JSON: " + error);
        }
    }

    Loader {
        id: processLoader
        active: false
        source: "SearchProcess.qml"
        onLoaded: service.start()
    }

    Connections {
        target: processLoader.item
        ignoreUnknownSignals: true
        function onProcessReady(): void {
            service.sendCatalogs();
            if (!rankDebounce.running)
                service.flush();
        }
        function onLineReceived(line: string): void { service.handleLine(line); }
        function onStopped(error: string): void {
            if (error.length > 0)
                console.warn("shelllist fuzzy search stopped: " + error);
            if (service.queuedRequests.length > 0)
                restartTimer.restart();
        }
    }

    Timer {
        id: rankDebounce
        interval: service.rankDebounceMs
        repeat: false
        onTriggered: if (service.ready) service.flush()
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: service.start()
    }
}
