import QtQuick
import QtTest
import Shelllist.Core as Core

TestCase {
    name: "KeyedListModel"

    Core.KeyedListModel {
        id: model
    }

    function init() {
        model.values = [];
        model.maximumIncrementalOrderChanges = 32;
        model.maximumSynchronousItems = 200;
        model.chunkSize = 64;
    }
    function rows(count, prefix) {
        return Array.from({
            length: count
        }, function (_, index) {
            return {
                key: (prefix || "row-") + index,
                title: "Row " + index
            };
        });
    }
    // Notifications tests own actual reply/action rendering and focused editor
    // survival through a 205-record burst, independent of model representation.
    function test_arbitraryStringKeysAndRepeatedReorders() {
        const keys = ["__proto__", "constructor", "toString", "", "a", "b"];
        for (let index = 0; index < 30; index++) {
            keys.push(keys.shift());
            model.values = keys.slice(0, index % keys.length + 1).map(function (key) {
                return {
                    key: key
                };
            });
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
        tryCompare(model, "count", 12);
        model.values = rows(20, "replacement-");
        model.values = [
            {
                key: "latest"
            }
        ];
        wait(0);
        compare(model.count, 1);
        compare(model.get(0).resultKey, "latest");
        model.values = rows(20);
        model.values = [];
        wait(0);
        compare(model.count, 0, "queued chunks must not resurrect cleared rows");
    }
}
