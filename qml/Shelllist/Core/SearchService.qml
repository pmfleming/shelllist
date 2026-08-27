pragma Singleton

import QtQuick

Item {
    id: service

    property int ownerSequence: 0
    property var queuedRequests: []
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

    function rank(owner: string, generation: int, query: string, items: var): void {
        const request = {
            owner: owner,
            generation: generation,
            query: query || "",
            items: (items || []).map(function (item) {
                return {
                    key: item.key,
                    title: item.title,
                    subtitle: item.subtitle,
                    keywords: item.keywords || [],
                    score: item.score || 0,
                    providerPriority: item.providerPriority || 0
                };
            })
        };
        // Requests that have not reached Rust yet can be superseded. Requests
        // already in flight are rejected by generation in ResultStore.
        queuedRequests = queuedRequests.filter(function (queued) {
            return queued.owner !== owner;
        }).concat([request]);
        if (!processLoader.active)
            processLoader.active = true;
        else if (ready)
            flush();
        else
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
        // qmllint disable missing-property
        for (let index = 0; index < requests.length; index++)
            processLoader.item["write"](JSON.stringify(requests[index]) + "\n");
        // qmllint enable missing-property
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
        function onProcessReady(): void { service.flush(); }
        function onLineReceived(line: string): void { service.handleLine(line); }
        function onStopped(error: string): void {
            if (error.length > 0)
                console.warn("shelllist fuzzy search stopped: " + error);
            if (service.queuedRequests.length > 0)
                restartTimer.restart();
        }
    }

    Timer {
        id: restartTimer
        interval: 1000
        repeat: false
        onTriggered: service.start()
    }
}
