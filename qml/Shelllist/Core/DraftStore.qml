import QtQuick

// Per-key drafts. `drafts` is replaced on every change so bindings observe it.
QtObject {
    property var drafts: ({})

    function draft(key: var): var {
        return drafts[key] || null;
    }
    // A falsy value removes the key.
    function put(key: var, value: var): void {
        const next = Object.assign({}, drafts);
        if (value)
            next[key] = value;
        else
            delete next[key];
        drafts = next;
    }
    function patch(key: var, changes: var): void {
        put(key, Object.assign({}, draft(key), changes));
    }
}
