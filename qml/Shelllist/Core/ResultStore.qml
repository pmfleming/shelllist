import QtQuick
import "Model.js" as Model

SelectionModel {
    id: resultStore

    required property ProviderRegistry registry
    property var sourceResults: []
    property int queryGeneration: 0
    property string activeQueryId: ""
    property string searchOwner: ""
    property int searchGeneration: 0
    property var rustRankedResults: []
    property bool hasRankedResults: false
    property double catalogUpdateStartedAtMs: 0
    property double searchRankRequestedAtMs: 0
    property double lastCatalogToModelLatencyMs: -1
    property double lastSearchRankLatencyMs: -1
    property bool rankRequestsEnabled: true
    property bool providerRankedResults: false
    // All ordering, including empty queries, belongs to Rust. Providers with
    // native ranked windows bypass this service without re-sorting their rows.
    // Retain the accepted window while pending; source order is startup-only.
    readonly property var visibleResults: !providerRankedResults && hasRankedResults ? rustRankedResults : sourceResults
    readonly property KeyedListModel visibleModel: visibleListModel
    count: visibleResults.length

    signal staleBatchIgnored(string providerId, string queryId)

    function selected(): var {
        return count === 0 ? null : visibleResults[clampIndex(selectedIndex)];
    }

    function requestRustRanking(): void {
        searchGeneration += 1;
        if (providerRankedResults) {
            hasRankedResults = false;
            rustRankedResults = [];
            SearchService.releaseOwner(searchOwner);
            return;
        }
        if (!rankRequestsEnabled) {
            SearchService.releaseOwner(searchOwner);
            return;
        }
        // An accepted empty window is still a window. Do not flash the entire
        // catalog while the next query or catalog revision is being ranked.
        if (rankRequestsEnabled && searchOwner.length > 0) {
            searchRankRequestedAtMs = Date.now();
            SearchService.rank(searchOwner, searchGeneration, queryText);
        }
    }

    function applyRustRanking(owner: string, generation: int, keys: var): void {
        if (providerRankedResults || owner !== searchOwner || generation !== searchGeneration)
            return;
        const previous = selected();
        const byKey = ({});
        sourceResults.forEach(function (item) {
            byKey[item.key] = item;
        });
        rustRankedResults = (keys || []).map(function (key) {
            return byKey[key];
        }).filter(function (item) {
            return !!item;
        });
        hasRankedResults = true;
        if (searchRankRequestedAtMs > 0) {
            lastSearchRankLatencyMs = Math.max(0, Date.now() - searchRankRequestedAtMs);
            searchRankRequestedAtMs = 0;
        }
        if (previous) {
            const retainedIndex = Model.indexByKey(visibleResults, previous.key);
            selectedIndex = retainedIndex >= 0 ? retainedIndex : clampIndex(selectedIndex);
        }
    }

    function beginQuery(text: string, context: var, providerIds: var, limit: int): var {
        if (activeQueryId.length > 0)
            registry.cancelQuery(activeQueryId);
        queryGeneration += 1;
        activeQueryId = "query-" + Date.now() + "-" + queryGeneration;
        // Assigning a different query resets selection through onQueryTextChanged.
        // A refresh of the same query must keep the stable result selection while
        // the replacement batch is in flight.
        queryText = text || "";
        const request = Model.queryRequest({
            id: activeQueryId,
            generation: queryGeneration,
            text: queryText,
            context: context || ({}),
            providerIds: providerIds || [],
            limit: limit || 50
        });
        registry.query(request);
        return request;
    }

    // Provider adapters already return Model.result() values. Keep that trusted
    // path separate from the public/raw path so a large catalog is validated
    // once instead of being cloned and normalized at every handoff.
    function replaceNormalizedProviderResults(providerId: string, values: var, resetSelection: bool): void {
        const itemProvider = registry.providerById(providerId);
        if (!itemProvider)
            throw new Error("results: unknown provider " + JSON.stringify(providerId));
        const previous = selected();
        const normalized = Array.isArray(values) ? values : [];
        const retained = sourceResults.filter(function (item) {
            return item.providerId !== providerId;
        });
        catalogUpdateStartedAtMs = Date.now();
        sourceResults = retained.concat(normalized);
        if (resetSelection || !previous) {
            selectedIndex = 0;
            return;
        }
        const retainedIndex = Model.indexByKey(visibleResults, previous.key);
        selectedIndex = retainedIndex >= 0 ? retainedIndex : Math.max(0, Math.min(selectedIndex, visibleResults.length - 1));
    }

    function replaceProviderResults(providerId: string, values: var, resetSelection: bool): void {
        const itemProvider = registry.providerById(providerId);
        if (!itemProvider)
            throw new Error("results: unknown provider " + JSON.stringify(providerId));
        const normalized = (values || []).map(function (value) {
            return Model.result(Object.assign({}, value, {
                providerId: providerId,
                providerPriority: itemProvider.priority
            }));
        });
        replaceNormalizedProviderResults(providerId, normalized, resetSelection);
    }

    function applyNormalizedBatch(value: var): bool {
        const batch = value || ({});
        const providerId = String(batch.providerId || "");
        const queryId = String(batch.queryId || "");
        if (!registry.providerById(providerId))
            throw new Error("results: unknown provider " + JSON.stringify(providerId));
        if (queryId.length > 0 && queryId !== activeQueryId) {
            staleBatchIgnored(providerId, queryId);
            return false;
        }
        if (batch.replace !== false) {
            replaceNormalizedProviderResults(providerId, batch.results, false);
            return true;
        }
        const byKey = ({});
        sourceResults.filter(function (item) {
            return item.providerId === providerId;
        }).forEach(function (item) {
            byKey[item.key] = item;
        });
        (batch.results || []).forEach(function (item) {
            byKey[item.key] = item;
        });
        replaceNormalizedProviderResults(providerId, Object.keys(byKey).map(function (key) {
            return byKey[key];
        }), false);
        return true;
    }

    function clear(): void {
        hasRankedResults = false;
        rustRankedResults = [];
        sourceResults = [];
        selectedIndex = 0;
        activeQueryId = "";
    }

    function recordCatalogToModelLatency(): void {
        if (catalogUpdateStartedAtMs <= 0)
            return;
        lastCatalogToModelLatencyMs = Math.max(0, Date.now() - catalogUpdateStartedAtMs);
        catalogUpdateStartedAtMs = 0;
    }

    onSourceResultsChanged: {
        if (rankRequestsEnabled && searchOwner.length > 0)
            SearchService.updateCatalog(searchOwner, sourceResults);
        requestRustRanking();
    }
    onQueryTextChanged: {
        selectedIndex = 0;
        requestRustRanking();
    }
    onProviderRankedResultsChanged: {
        if (!providerRankedResults && rankRequestsEnabled && searchOwner.length > 0)
            SearchService.updateCatalog(searchOwner, sourceResults);
        requestRustRanking();
    }
    onRankRequestsEnabledChanged: {
        if (rankRequestsEnabled && searchOwner.length > 0)
            SearchService.updateCatalog(searchOwner, sourceResults);
        requestRustRanking();
    }
    onVisibleResultsChanged: selectedIndex = clampIndex(selectedIndex)

    Component.onCompleted: {
        searchOwner = SearchService.allocateOwner();
        if (rankRequestsEnabled)
            SearchService.updateCatalog(searchOwner, sourceResults);
        requestRustRanking();
    }

    Component.onDestruction: SearchService.releaseOwner(searchOwner)

    Connections {
        target: SearchService
        function onRanked(owner: string, generation: int, keys: var): void {
            resultStore.applyRustRanking(owner, generation, keys);
        }
    }

    KeyedListModel {
        id: visibleListModel
        values: resultStore.visibleResults
        onChunkApplied: resultStore.recordCatalogToModelLatency()
    }
}
