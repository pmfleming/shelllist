import QtQuick
import "Model.js" as Model

Item {
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
    property int maximumIncrementalOrderChanges: 32
    property bool rankRequestsEnabled: true
    readonly property bool fuzzyQuery: queryText.trim().length > 0
    readonly property var baselineResults: Model.rankResults(sourceResults, "")
    // Fuzzy work belongs to the Rust matcher. While a request is pending, keep
    // the previous keyed model (or the unfiltered baseline for the first edit)
    // instead of ranking the same catalog synchronously on the UI thread.
    readonly property var visibleResults: fuzzyQuery
        ? appliedSearchGeneration === searchGeneration
            ? rustRankedResults
            : rustRankedResults.length > 0 ? rustRankedResults : baselineResults
        : baselineResults
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
        if (rankRequestsEnabled)
            SearchService.rank(searchOwner, searchGeneration, queryText, sourceResults);
    }

    function applyRustRanking(owner: string, generation: int, keys: var): void {
        if (owner !== searchOwner || generation !== searchGeneration)
            return;
        const previous = selected();
        const byKey = ({});
        sourceResults.forEach(function (item) { byKey[item.key] = item; });
        rustRankedResults = (keys || []).map(function (key) { return byKey[key]; })
            .filter(function (item) { return !!item; });
        appliedSearchGeneration = generation;
        if (previous) {
            const retainedIndex = Model.indexByKey(visibleResults, previous.key);
            selectedIndex = retainedIndex >= 0 ? retainedIndex : clampIndex(selectedIndex);
        }
    }

    function clampIndex(index: int): int {
        return count <= 0 ? 0 : Math.max(0, Math.min(index, count - 1));
    }

    function move(delta: int): void { selectedIndex = clampIndex(selectedIndex + delta); }
    function selectFirst(): void { selectedIndex = 0; }

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

    function replaceProviderResults(providerId: string, values: var, resetSelection: bool): void {
        const itemProvider = registry.providerById(providerId);
        if (!itemProvider)
            throw new Error("results: unknown provider " + JSON.stringify(providerId));
        const previous = selected();
        const normalized = (values || []).map(function (value) {
            const candidate = Object.assign({}, value, {
                providerId: providerId,
                providerPriority: itemProvider.priority
            });
            return Model.result(candidate);
        });
        const retained = sourceResults.filter(function (item) { return item.providerId !== providerId; });
        const next = Model.resultList(retained.concat(normalized));
        sourceResults = next;
        if (resetSelection || !previous) {
            selectedIndex = 0;
            return;
        }
        const retainedIndex = Model.indexByKey(visibleResults, previous.key);
        selectedIndex = retainedIndex >= 0 ? retainedIndex : Math.max(0, Math.min(selectedIndex, visibleResults.length - 1));
    }

    function applyBatch(value: var): bool {
        const batch = Model.resultBatch(value);
        if (batch.queryId.length > 0 && batch.queryId !== activeQueryId) {
            staleBatchIgnored(batch.providerId, batch.queryId);
            return false;
        }
        if (batch.replace) {
            replaceProviderResults(batch.providerId, batch.results, false);
            return true;
        }
        const existing = sourceResults.filter(function (item) { return item.providerId === batch.providerId; });
        const byKey = ({});
        existing.forEach(function (item) { byKey[item.key] = item; });
        batch.results.forEach(function (item) { byKey[item.key] = item; });
        replaceProviderResults(batch.providerId, Object.keys(byKey).map(function (key) { return byKey[key]; }), false);
        return true;
    }

    function clear(): void {
        sourceResults = [];
        selectedIndex = 0;
        activeQueryId = "";
    }

    function rebuildVisibleModel(): void {
        visibleListModel.clear();
        for (let index = 0; index < visibleResults.length; index++) {
            const result = visibleResults[index];
            visibleListModel.append({ resultKey: result.key, resultData: result });
        }
    }

    function currentModelOrder(): var {
        const keys = [];
        for (let index = 0; index < visibleListModel.count; index++)
            keys.push(visibleListModel.get(index).resultKey);
        return keys;
    }

    function orderChangeCount(currentKeys: var): int {
        const largest = Math.max(currentKeys.length, visibleResults.length);
        let changed = Math.abs(currentKeys.length - visibleResults.length);
        const shared = Math.min(currentKeys.length, visibleResults.length);
        for (let index = 0; index < shared; index++) {
            if (currentKeys[index] !== visibleResults[index].key)
                changed += 1;
            if (changed > maximumIncrementalOrderChanges)
                return changed;
        }
        return Math.min(changed, largest);
    }

    function refreshIndexes(keys: var, indexes: var, from: int, to: int): void {
        const first = Math.max(0, Math.min(from, to));
        const last = Math.min(keys.length - 1, Math.max(from, to));
        for (let index = first; index <= last; index++)
            indexes[keys[index]] = index;
    }

    function syncVisibleModel(): void {
        const keys = currentModelOrder();
        if (orderChangeCount(keys) > maximumIncrementalOrderChanges) {
            rebuildVisibleModel();
            return;
        }

        const indexes = ({});
        for (let index = 0; index < keys.length; index++)
            indexes[keys[index]] = index;

        for (let desiredIndex = 0; desiredIndex < visibleResults.length; desiredIndex++) {
            const desired = visibleResults[desiredIndex];
            const found = indexes[desired.key];
            if (found === undefined) {
                visibleListModel.insert(desiredIndex,
                    { resultKey: desired.key, resultData: desired });
                keys.splice(desiredIndex, 0, desired.key);
                refreshIndexes(keys, indexes, desiredIndex, keys.length - 1);
                continue;
            }
            const currentIndex = Number(found);
            if (currentIndex !== desiredIndex) {
                visibleListModel.move(currentIndex, desiredIndex, 1);
                keys.splice(desiredIndex, 0, keys.splice(currentIndex, 1)[0]);
                refreshIndexes(keys, indexes, currentIndex, desiredIndex);
            }
            visibleListModel.setProperty(desiredIndex, "resultData", desired);
        }
        if (visibleListModel.count > visibleResults.length)
            visibleListModel.remove(visibleResults.length, visibleListModel.count - visibleResults.length);
    }

    onSourceResultsChanged: requestRustRanking()
    onQueryTextChanged: {
        selectedIndex = 0;
        requestRustRanking();
    }
    onVisibleResultsChanged: {
        selectedIndex = clampIndex(selectedIndex);
        syncVisibleModel();
    }

    Component.onCompleted: {
        searchOwner = SearchService.allocateOwner();
        requestRustRanking();
    }

    Connections {
        target: SearchService
        function onRanked(owner: string, generation: int, keys: var): void {
            applyRustRanking(owner, generation, keys);
        }
    }

    ListModel {
        id: visibleListModel
        dynamicRoles: true
    }
}
