import QtQuick

// Values have unique, stable string keys. Keep delegate roles common to chooser
// results and bar descriptors; presentation and selection stay with consumers.
ListModel {
    property var values: []
    property int maximumIncrementalOrderChanges: 32
    property int maximumSynchronousItems: 200
    property int chunkSize: 64
    property int generation: 0
    property int pendingIndex: 0
    property var pendingValues: []
    dynamicRoles: true

    signal chunkApplied

    function equivalent(left: var, right: var): bool {
        return left === right;
    }

    function appendChunk(expectedGeneration: int): void {
        if (expectedGeneration !== generation)
            return;
        const size = pendingValues.length > maximumSynchronousItems ? Math.max(1, chunkSize) : pendingValues.length;
        const end = Math.min(pendingIndex + size, pendingValues.length);
        while (pendingIndex < end) {
            const value = pendingValues[pendingIndex++];
            append({
                resultKey: value.key,
                resultData: value
            });
        }
        chunkApplied();
        if (pendingIndex < pendingValues.length)
            Qt.callLater(appendChunk, expectedGeneration);
        else
            pendingValues = [];
    }

    function currentKeys(): var {
        const keys = [];
        for (let index = 0; index < count; index++)
            keys.push(get(index).resultKey);
        return keys;
    }

    function orderChanges(keys: var): int {
        let changed = Math.abs(keys.length - values.length);
        const shared = Math.min(keys.length, values.length);
        for (let index = 0; index < shared && changed <= maximumIncrementalOrderChanges; index++) {
            if (keys[index] !== values[index].key)
                changed++;
        }
        return changed;
    }

    function refreshIndexes(keys: var, indexes: var, from: int, to: int): void {
        const first = Math.max(0, Math.min(from, to));
        const last = Math.min(keys.length - 1, Math.max(from, to));
        for (let index = first; index <= last; index++)
            indexes[keys[index]] = index;
    }

    function reconcile(keys: var): void {
        const indexes = Object.create(null);
        refreshIndexes(keys, indexes, 0, keys.length - 1);
        for (let desiredIndex = 0; desiredIndex < values.length; desiredIndex++) {
            const value = values[desiredIndex];
            const found = indexes[value.key];
            if (found === undefined) {
                insert(desiredIndex, {
                    resultKey: value.key,
                    resultData: value
                });
                keys.splice(desiredIndex, 0, value.key);
                refreshIndexes(keys, indexes, desiredIndex, keys.length - 1);
                continue;
            }
            if (found !== desiredIndex) {
                move(found, desiredIndex, 1);
                keys.splice(desiredIndex, 0, keys.splice(found, 1)[0]);
                refreshIndexes(keys, indexes, found, desiredIndex);
            }
            if (!equivalent(get(desiredIndex).resultData, value))
                setProperty(desiredIndex, "resultData", value);
        }
        if (count > values.length)
            remove(values.length, count - values.length);
        chunkApplied();
    }

    function sync(): void {
        generation++;
        pendingValues = [];
        pendingIndex = 0;
        const keys = currentKeys();
        // Large history pages are append-only, not a reorder. Preserve existing
        // delegates (and the viewport) instead of crossing the reset threshold.
        if (values.length > keys.length && keys.every(function (key, index) { return key === values[index].key; })) {
            for (let index = 0; index < keys.length; index++) {
                if (!equivalent(get(index).resultData, values[index]))
                    setProperty(index, "resultData", values[index]);
            }
            pendingValues = values.slice(keys.length);
            appendChunk(generation);
            return;
        }
        if (orderChanges(keys) <= maximumIncrementalOrderChanges) {
            reconcile(keys);
            return;
        }
        pendingValues = values.slice();
        clear();
        appendChunk(generation);
    }

    onValuesChanged: sync()
}
