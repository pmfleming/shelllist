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
        Lifecycle, calls, cancelled, now: 10 * 86400000,
        resourcesVisible: true, selectedResult: { id: "A" },
        resourceHistory: [], pendingResourceHistory: [], historyTargetId: "",
        activeHistoryRequestId: "", historyWindowStartMs: 0, historyWindowEndMs: 0,
        historyRange: "30m", historyRequestRange: "", revisionRequestId: "",
        historyCursor: "", pendingHistoryCursor: "",
        backend: {
            nextRequestId: () => "history-" + (++sequence),
            history: (...args) => { calls.push(args); return true; },
            cancelRequest: id => cancelled.push(id)
        }
    };
    state.Date = { now: () => state.now };
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

function respond(c, points, cursor, hasMore = false) {
    c.applyResourceHistory(c.activeHistoryRequestId,
        { target_id: c.historyTargetId, points, next_cursor: cursor, has_more: hasMore });
}

{
    const c = controller();
    c.requestResourceHistory();
    respond(c, [{ timestamp_ms: c.now - 15000 }], "A-last");
    assert.equal(c.resourceHistory.length, 1);
    c.requestResourceHistory(true);
    const staleId = c.activeHistoryRequestId;
    c.selectedResult = { id: "B" };
    c.requestResourceHistory();
    assert.equal(c.historyTargetId, "B");
    assert.equal(c.resourceHistory.length, 0, "never display A's history under B");
    assert.equal(c.calls.at(-1)[3], null, "new target resets the cursor");
    assert.ok(c.cancelled.includes(staleId), "cancel superseded pagination");
    c.applyResourceHistory(staleId, { target_id: "A", points: [{ timestamp_ms: c.now }], has_more: true, next_cursor: "old" });
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
    c.applyResourceHistory(oldId, { target_id: "A", points: [{ timestamp_ms: c.now }], has_more: false });
    assert.equal(c.resourceHistory.length, 0, "old range cannot populate the new selection");
    respond(c, [{ timestamp_ms: c.now }], "24h-last");
    assert.equal(c.resourceHistory[0].timestamp_ms, c.now);
    c.selectHistoryRange("2h");
    assert.equal(c.calls.at(-1)[3], null, "new range resets the cursor");
    assert.equal(c.resourceHistory.length, 0);
}

{
    const c = controller();
    c.historyRange = "24h";
    c.requestResourceHistory();
    assert.equal(c.calls[0][3], null);
    const points = Array.from({ length: 5760 }, (_, index) => ({
        timestamp_ms: c.now - (5760 - index) * 15000
    }));
    for (let start = 0; start < points.length; start += 1000) {
        const end = Math.min(start + 1000, points.length);
        respond(c, points.slice(start, end), "cursor-" + end, end < points.length);
    }
    assert.equal(c.resourceHistory.length, 5760);
    assert.equal(c.calls.length, 6);
    assert.equal(c.historyCursor, "cursor-5760");
    c.now += 15000;
    c.requestResourceHistory(true);
    assert.equal(c.calls.at(-1)[3], "cursor-5760", "poll from the committed cursor, not the range start");
    respond(c, [{ timestamp_ms: c.now - 15000 }], "cursor-5761");
    assert.equal(c.calls.length, 7, "steady-state refresh needs only the new page");
    assert.equal(c.resourceHistory.length, 5760, "append new buckets and prune the sliding range");
    assert.equal(c.resourceHistory[0].timestamp_ms, points[1].timestamp_ms);
    c.requestResourceHistory(true);
    const retained = c.resourceHistory;
    respond(c, [], null);
    assert.equal(c.historyCursor, "cursor-5761", "empty polls must retain the last cursor");
    assert.equal(c.resourceHistory, retained, "unchanged data does not rebuild the history array");
}

{
    const c = controller();
    c.requestResourceHistory();
    respond(c, [{ timestamp_ms: c.now - 30000 }], "one");
    c.requestResourceHistory(true);
    respond(c, [{ timestamp_ms: c.now - 15000 }], "two", true);
    c.handleFailure(c.activeHistoryRequestId, "timeout");
    assert.equal(c.historyCursor, "one", "failed pagination does not advance the committed cursor");
    assert.equal(c.resourceHistory.length, 1);
    c.requestResourceHistory(true);
    assert.equal(c.calls.at(-1)[3], "one");
    respond(c, [{ timestamp_ms: c.now - 30000 }, { timestamp_ms: c.now - 15000 }], "two");
    assert.equal(c.resourceHistory.length, 2, "overlapping pages are deduplicated");
    c.requestResourceHistory(true);
    respond(c, [], "two", true);
    assert.equal(c.historyInFlight, false, "nonadvancing cursors cannot loop forever");
    assert.equal(c.historyCursor, "two");
}

console.log("application history: target/range isolation, incremental pagination, pruning and recovery passed");
