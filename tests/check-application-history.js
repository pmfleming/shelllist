#!/usr/bin/env node
// Execute the controller's actual history handlers without requiring a compositor.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");
const path = require("node:path");
const launcher = path.resolve(process.argv[2] || path.join(__dirname, "../launcher"));
const source = fs.readFileSync(path.join(launcher, "ApplicationController.qml"), "utf8");
const Lifecycle = {};
vm.createContext(Lifecycle);
vm.runInContext(fs.readFileSync(path.join(launcher, "ApplicationLifecycle.js"), "utf8")
    .replace(/^\.pragma library\s*/, ""), Lifecycle);

function controller() {
    const calls = [];
    let sequence = 0;
    const state = {
        Lifecycle, calls, now: 10 * 86400000,
        // This fixture has no application actions in flight. Their failure
        // handlers decline history IDs so the controller owns history recovery.
        operations: { fail: () => false, statusFailed: () => false },
        resourcesVisible: true, selectedResult: { id: "A" },
        resourceHistory: [], pendingResourceHistory: [], resourceHistorySummary: null, pendingHistorySummary: null, historyTargetId: "",
        activeHistoryRequestId: "", historyWindowStartMs: 0, historyWindowEndMs: 0,
        historyRange: "30m", historyRequestRange: "", revisionRequestId: "",
        historyCursor: "", pendingHistoryCursor: "",
        backend: {
            nextRequestId: () => "history-" + (++sequence),
            history: (...args) => { calls.push(args); return true; },
            cancel() {}
        }
    };
    state.Date = { now: () => state.now };
    Object.defineProperty(state, "historyInFlight", { get: () => !!state.activeHistoryRequestId });
    vm.createContext(state);
    for (const name of ["clearResourceHistory", "resourceHistorySinceMs", "nextHistoryRequestId",
            "requestResourceHistory", "applyResourceHistory", "handleFailure"]) {
        const match = source.match(new RegExp("    function " + name
            + "\\((.*?)\\): \\w+ \\{([\\s\\S]*?)\\n    \\}"));
        vm.runInContext("function " + name + "(" + match[1].replace(/: \w+/g, "")
            + ") {" + match[2] + "\n}", state);
    }
    return state;
}

function respond(c, points, cursor, hasMore = false) {
    c.applyResourceHistory(c.activeHistoryRequestId,
        { target_id: c.historyTargetId, points, next_cursor: cursor, has_more: hasMore,
          summary: { window_start_ms: c.historyWindowStartMs, window_end_ms: c.historyWindowEndMs, revision: "stable", metrics: {} } });
}

{
    const c = controller();
    c.historyRange = "24h";
    c.requestResourceHistory();
    const points = Array.from({ length: 5760 }, (_, index) => ({
        timestamp_ms: c.now - (5760 - index) * 15000
    }));
    for (let start = 0; start < points.length; start += 1000) {
        const end = Math.min(start + 1000, points.length);
        respond(c, points.slice(start, end), "cursor-" + end, end < points.length);
    }
    c.now += 15000;
    c.requestResourceHistory(true);
    const cursor = c.calls.at(-1)[3];
    respond(c, [{ timestamp_ms: c.now - 15000 }], "cursor-5761");
    assert.deepEqual({cursor, points: c.resourceHistory.length}, {cursor: "cursor-5760", points: 5760},
        "poll from the committed cursor and prune the sliding window");
}

{
    const c = controller();
    c.requestResourceHistory();
    respond(c, [{ timestamp_ms: c.now - 30000 }], "one");
    c.requestResourceHistory(true);
    respond(c, [{ timestamp_ms: c.now - 15000 }], "two", true);
    c.handleFailure(c.activeHistoryRequestId, "timeout");
    c.requestResourceHistory(true);
    const cursor = c.calls.at(-1)[3];
    respond(c, [{ timestamp_ms: c.now - 30000 }, { timestamp_ms: c.now - 15000 }], "two");
    c.requestResourceHistory(true);
    respond(c, [], "two", true);
    assert.deepEqual({cursor, points: c.resourceHistory.length, pending: c.historyInFlight},
        {cursor: "one", points: 2, pending: false}, "retry uses the committed cursor, deduplicates overlaps and stops nonadvancing pages");
}

console.log("application history: pagination and recovery passed");
