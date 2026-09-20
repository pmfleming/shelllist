import QtQuick
import "Model.js" as Model

Item {
    id: resultStore

    required property ProviderRegistry registry
    property var sourceResults: []
    property string queryText: ""
    property int selectedIndex
    property int queryGeneration: 0
    property string activeQueryId: ""
    property string searchOwner: ""
    property int searchGeneration: 0
    property int appliedSearchGeneration: -1
    property var rustRankedResults: []
    property double catalogUpdateStartedAtMs: 0
    property double searchRankRequestedAtMs: 0
    property double lastCatalogToModelLatencyMs: -1
    property double lastSearchRankLatencyMs: -1
    property bool rankRequestsEnabled: true
    property bool providerRankedResults: false
    readonly property bool fuzzyQuery: !providerRankedResults && queryText.trim().length > 0
    readonly property var baselineResults: Model.rankResults(sourceResults, "")
    // Fuzzy work belongs to the Rust matcher. While a request is pending, keep
    // the previous keyed model (or the unfiltered baseline for the first edit)
    // instead of ranking the same catalog synchronously on the UI thread.
    readonly property var visibleResults: fuzzyQuery ? appliedSearchGeneration === searchGeneration ? rustRankedResults : rustRankedResults.length > 0 ? rustRankedResults : baselineResults : baselineResults
    readonly property var visibleModel: visibleListModel
    readonly property int count: visibleResults.length

    signal staleBatchIgnored(string providerId, string queryId)

    function selected(): var {
        return count === 0 ? null : visibleResults[clampIndex(selectedIndex)];
    }

    function requestRustRanking(): void {
        searchGeneration += 1;
        appliedSearchGeneration = -1;
        if (!fuzzyQuery) {
            rustRankedResults = [];
            return;
        }
        if (rustRankedResults.length === 0)
            rustRankedResults = baselineResults;
        if (rankRequestsEnabled && searchOwner.length > 0) {
            searchRankRequestedAtMs = Date.now();
            SearchService.rank(searchOwner, searchGeneration, queryText);
        }
    }

    function applyRustRanking(owner: string, generation: int, keys: var): void {
        if (owner !== searchOwner || generation !== searchGeneration)
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
        appliedSearchGeneration = generation;
        if (searchRankRequestedAtMs > 0) {
            lastSearchRankLatencyMs = Math.max(0, Date.now() - searchRankRequestedAtMs);
            searchRankRequestedAtMs = 0;
        }
        if (previous) {
            const retainedIndex = Model.indexByKey(visibleResults, previous.key);
            selectedIndex = retainedIndex >= 0 ? retainedIndex : clampIndex(selectedIndex);
        }
    }

    function clampIndex(index: int): int {
        return count <= 0 ? 0 : Math.max(0, Math.min(index, count - 1));
    }

    function move(delta: int): void {
        selectedIndex = clampIndex(selectedIndex + delta);
    }
    function selectFirst(): void {
        selectedIndex = 0;
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

    function applyBatch(value: var): bool {
        return applyNormalizedBatch(Model.resultBatch(value));
    }

    function clear(): void {
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
    onVisibleResultsChanged: selectedIndex = clampIndex(selectedIndex)

    Component.onCompleted: {
        searchOwner = SearchService.allocateOwner();
        if (rankRequestsEnabled)
            SearchService.updateCatalog(searchOwner, sourceResults);
        requestRustRanking();
    }

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
