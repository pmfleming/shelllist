import QtQuick
import "Model.js" as Model

Item {
    id: store

    required property ProviderRegistry registry
    property var sourceResults: []
    property string queryText: ""
    property int selectedIndex
    property int queryGeneration: 0
    property string activeQueryId: ""
    readonly property var visibleResults: Model.rankResults(sourceResults, queryText)
    readonly property var visibleModel: visibleListModel
    readonly property int count: visibleResults.length

    signal staleBatchIgnored(string providerId, string queryId)
    signal providerQueryFailed(var error)

    function selected() {
        return count === 0 ? null : visibleResults[clampIndex(selectedIndex)];
    }

    function clampIndex(index) {
        return count <= 0 ? 0 : Math.max(0, Math.min(index, count - 1));
    }

    function move(delta) { selectedIndex = clampIndex(selectedIndex + delta); }
    function selectFirst() { selectedIndex = 0; }

    function beginQuery(text, context, providerIds, limit) {
        if (activeQueryId.length > 0)
            registry.cancelQuery(activeQueryId);
        queryGeneration += 1;
        activeQueryId = "query-" + Date.now() + "-" + queryGeneration;
        queryText = text || "";
        selectedIndex = 0;
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

    function replaceProviderResults(providerId, values, resetSelection) {
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

    function applyBatch(value) {
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

    function clear() {
        sourceResults = [];
        selectedIndex = 0;
        activeQueryId = "";
    }

    function modelIndexFor(key, startIndex) {
        for (let index = startIndex; index < visibleListModel.count; index++)
            if (visibleListModel.get(index).resultKey === key)
                return index;
        return -1;
    }

    function syncVisibleModel() {
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

    onQueryTextChanged: selectedIndex = 0
    onVisibleResultsChanged: {
        selectedIndex = clampIndex(selectedIndex);
        syncVisibleModel();
    }

    ListModel {
        id: visibleListModel
        dynamicRoles: true
    }

    Connections {
        target: store.registry
        function onQueryBatchReceived(batch) { store.applyBatch(batch); }
        function onQueryFailed(error) { store.providerQueryFailed(error); }
    }
}
