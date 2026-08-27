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
    readonly property bool fuzzyQuery: queryText.trim().length > 0
    readonly property var visibleResults: fuzzyQuery && appliedSearchGeneration === searchGeneration
        ? rustRankedResults : Model.rankResults(sourceResults, queryText)
    readonly property var visibleModel: visibleListModel
    readonly property int count: visibleResults.length

    signal staleBatchIgnored(string providerId, string queryId)

    function selected(): var {
        return count === 0 ? null : visibleResults[clampIndex(selectedIndex)];
    }

    function requestRustRanking(): void {
        searchGeneration += 1;
        appliedSearchGeneration = -1;
        rustRankedResults = [];
        if (fuzzyQuery)
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

    function modelIndexFor(key: string, startIndex: int): int {
        for (let index = startIndex; index < visibleListModel.count; index++)
            if (visibleListModel.get(index).resultKey === key)
                return index;
        return -1;
    }

    function syncVisibleModel(): void {
        for (let desiredIndex = 0; desiredIndex < visibleResults.length; desiredIndex++) {
            const desired = visibleResults[desiredIndex];
            const currentIndex = modelIndexFor(desired.key, desiredIndex);
            if (currentIndex < 0) {
                visibleListModel.insert(desiredIndex, { resultKey: desired.key, resultData: desired });
            } else {
                if (currentIndex !== desiredIndex)
                    visibleListModel.move(currentIndex, desiredIndex, 1);
                visibleListModel.setProperty(desiredIndex, "resultData", desired);
            }
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
