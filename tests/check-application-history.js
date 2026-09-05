#!/usr/bin/env node
// Execute the controller's actual history handlers without requiring a compositor.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const launcher = path.resolve(__dirname, "../launcher");
const source = fs.readFileSync(path.join(launcher, "ApplicationController.qml"), "utf8");
const Lifecycle = {};
vm.createContext(Lifecycle);
vm.runInContext(fs.readFileSync(path.join(launcher, "ApplicationLifecycle.js"), "utf8")
    .replace(/^\.pragma library\s*/, ""), Lifecycle);

function controller() {
    const calls = [], cancelled = [];
    let sequence = 0;
    const state = {
        Lifecycle, calls, cancelled,
        resourcesVisible: true, selectedResult: { id: "A" },
        resourceHistory: [], pendingResourceHistory: [], historyTargetId: "",
        activeHistoryRequestId: "", historyWindowStartMs: 0, historyWindowEndMs: 0,
        historyRange: "30m", historyRequestRange: "", revisionRequestId: "",
        backend: {
            nextRequestId: () => "history-" + (++sequence),
            history: (...args) => { calls.push(args); return true; },
            cancelRequest: id => cancelled.push(id)
        }
    };
    Object.defineProperty(state, "historyInFlight", { get: () => !!state.activeHistoryRequestId });
    vm.createContext(state);
    for (const name of ["clearResourceHistory", "resourceHistorySinceMs", "nextHistoryRequestId",
            "requestResourceHistory", "applyResourceHistory", "selectHistoryRange", "handleFailure"]) {
        const match = source.match(new RegExp("    function " + name
            + "\\((.*?)\\): \\w+ \\{([\\s\\S]*?)\\n    \\}"));
        assert.ok(match, "missing controller handler: " + name);
        vm.runInContext("function " + name + "(" + match[1].replace(/: \w+/g, "")
            + ") {" + match[2] + "\n}", state);
    }
    return state;
}

{
    const c = controller();
    c.requestResourceHistory();
    const firstId = c.activeHistoryRequestId;
    c.applyResourceHistory(firstId, { target_id: "A", points: [{ timestamp_ms: 1 }], has_more: false });
    assert.equal(c.resourceHistory.length, 1);
    c.requestResourceHistory(true);
    const staleId = c.activeHistoryRequestId;
    c.selectedResult = { id: "B" };
    c.requestResourceHistory();
    assert.equal(c.historyTargetId, "B");
    assert.equal(c.resourceHistory.length, 0, "never display A's history under B");
    assert.ok(c.cancelled.includes(staleId), "cancel superseded pagination");
    c.applyResourceHistory(staleId, { target_id: "A", points: [{ timestamp_ms: 2 }], has_more: true, next_cursor: "old" });
    assert.equal(c.resourceHistory.length, 0, "ignore late responses for A");
    c.handleFailure(c.activeHistoryRequestId, "unavailable");
    assert.equal(c.resourceHistory.length, 0, "failure must not retain another target's history");
}

{
    const c = controller();
    c.requestResourceHistory();
    const oldId = c.activeHistoryRequestId;
    const oldSince = c.calls[0][2];
    c.requestResourceHistory(true);
    assert.equal(c.calls.length, 1, "periodic refresh must not interrupt pagination");
    c.selectHistoryRange("24h");
    assert.equal(c.calls.length, 2, "range changes supersede in-flight requests immediately");
    assert.equal(c.historyRequestRange, "24h");
    assert.ok(c.calls[1][2] < oldSince - 23 * 60 * 60 * 1000);
    assert.ok(c.cancelled.includes(oldId));
    c.applyResourceHistory(oldId, { target_id: "A", points: [{ timestamp_ms: 1 }], has_more: false });
    assert.equal(c.resourceHistory.length, 0, "old range cannot populate the new selection");
    c.applyResourceHistory(c.activeHistoryRequestId,
        { target_id: "A", points: [{ timestamp_ms: 2 }], has_more: false });
    assert.equal(c.resourceHistory[0].timestamp_ms, 2);
}

console.log("application history: target isolation and range supersession checks passed");
