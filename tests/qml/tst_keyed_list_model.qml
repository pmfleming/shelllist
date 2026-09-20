pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    id: testCase
    name: "KeyedListModel"
    property int creations: 0

    Core.KeyedListModel { id: model }
    Repeater {
        id: delegates
        model: model
        delegate: Item {
            required property var resultData
            objectName: resultData.title || ""
            Component.onCompleted: testCase.creations++
        }
    }

    function init() {
        model.values = [];
        model.maximumIncrementalOrderChanges = 32;
        model.maximumSynchronousItems = 200;
        model.chunkSize = 64;
        creations = 0;
    }
    function rows(count, prefix) {
        return Array.from({length: count}, function (_, index) {
            return {key: (prefix || "row-") + index, title: "Row " + index};
        });
    }
    function test_preservesDelegatesThroughMoveInsertRemoveAndUpdate() {
        model.values = rows(3);
        const first = delegates.itemAt(0);
        const last = delegates.itemAt(2);
        compare(creations, 3);
        model.values = [{key: "row-2", title: "Changed"}, {key: "new"}, {key: "row-0"}];
        compare(model.count, 3);
        compare(delegates.itemAt(0), last);
        compare(delegates.itemAt(2), first);
        compare(last.objectName, "Changed");
        compare(creations, 4, "insert only the new delegate; do not reset the list");
    }
    function test_arbitraryStringKeysAndRepeatedReorders() {
        const keys = ["__proto__", "constructor", "toString", "", "a", "b"];
        for (let index = 0; index < 30; index++) {
            keys.push(keys.shift());
            model.values = keys.slice(0, index % keys.length + 1).map(function (key) { return {key: key}; });
            compare(model.count, model.values.length);
            for (let row = 0; row < model.count; row++)
                compare(model.get(row).resultKey, model.values[row].key);
        }
    }
    function test_progressiveRebuildAndStaleWorkCancellation() {
        model.maximumIncrementalOrderChanges = 2;
        model.maximumSynchronousItems = 5;
        model.chunkSize = 2;
        model.values = rows(12);
        compare(model.count, 2, "first chunk is synchronous");
        tryCompare(model, "count", 12);
        model.values = rows(20, "replacement-");
        compare(model.count, 2);
        model.values = [{key: "latest"}];
        wait(0);
        compare(model.count, 1);
        compare(model.get(0).resultKey, "latest");
        model.values = rows(20);
        model.values = [];
        wait(0);
        compare(model.count, 0, "queued chunks must not resurrect cleared rows");
    }
}
