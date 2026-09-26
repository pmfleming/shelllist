#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const assert = require("assert/strict");
const vm = require("vm");

const root = process.argv[2];
if (!root)
    throw new Error("usage: check-daemon-boundary.js <shelllist-root>");

function source(relative) {
    return fs.readFileSync(path.join(root, relative), "utf8");
}

function install(context, text) {
    vm.createContext(context);
    vm.runInContext(text.match(/^    function [\s\S]*?^    }/gm).join("\n")
        .replace(/:\s*(string|bool|var|int|real|void)\b/g, ""), context);
}
const quietConsole = { info() {}, warn() {}, error() {} };
const transport = source("qml/Shelllist/Io/process/JsonlDaemonClient.qml");
for (const failure of ["start", "exit", "recovered-exit"]) {
    const writes = [];
    const client = { active: true, ready: false, daemonName: "test-daemon",
        queuedLines: ["destructive-effect"], counters: { retryAttempt: 0 },
        initialRetryInterval: 1500, maximumRetryInterval: 30000,
        console: quietConsole, processError: { text: "crashed" },
        process: { running: false, exec() { throw new Error("start failed"); }, write: line => writes.push(line) },
        retryTimer: { running: false, restart() { this.running = true; } },
        transportFailed() {} };
    client.client = client;
    client.retiring = failure === "recovered-exit";
    install(client, transport);
    if (failure === "start") client.start();
    else {
        const body = transport.match(/onExited: function \(exitCode\) \{[^\n]*\n([\s\S]*?)\n        \}/)[1];
        vm.runInContext("function exited(exitCode) {" + body + "\n}", client);
        client.exited(failure === "recovered-exit" ? 0 : 1);
    }
    client.ready = true;
    client.flushQueue();
    assert.deepEqual(writes, [], `${failure}: failed-generation effects must never replay`);
}

// Exercise compatibility and gap handling through the consumer, rather than
// checking that a particular helper name occurs in the backend's source.
{
    const received = [], gaps = [], ApiEnvelope = {};
    install(ApiEnvelope, source("qml/Shelllist/Core/ApiEnvelope.qml"));
    const backend = { Core: { ApiEnvelope }, expectedProtocol: "test-api", expectedVersion: 1,
        daemonName: "test-daemon", console: quietConsole,
        eventReceived: event => received.push(event), eventGapDetected: stream => gaps.push(stream) };
    install(backend, source("qml/Shelllist/Io/DaemonBackend.qml"));
    const event = { protocol: "test-api", version: 1, stream: "updates", event: "changed", data: {} };
    backend.acceptSharedEvent({ ...event, protocol: "wrong-api" });
    backend.acceptSharedEvent({ ...event, version: 2 });
    backend.acceptSharedEvent({ ...event, stream: "" });
    backend.acceptSharedEvent({ ...event, event: "lagged" });
    backend.acceptSharedEvent(event);
    assert.deepEqual(received, [event], "only compatible ordinary events reach consumers");
    assert.deepEqual(gaps, ["updates"], "gaps trigger resynchronization, not normal updates");
}

// Extra subscriptions must be cancelled by daemon ID, even if the view closes
// before the reply. Neither subscribe replies nor lost IDs leak to feature code.
for (const closeBeforeReply of [false, true]) {
    const cancellations = [];
    const backend = {
        pending: {}, extraSubscriptions: {}, extraSubscriptionCancellations: {},
        subscriptionSequence: 0, daemonName: "test-daemon", sharedConsumerId: "view",
        console: quietConsole,
        DaemonSessions: { subscribe() {}, cancel: (...args) => cancellations.push(args) },
        responseReceived() { throw new Error("subscription reply escaped"); },
        transportFailed() {}
    };
    install(backend, source("qml/Shelllist/Io/DaemonBackend.qml"));
    const id = backend.subscribeStreams(["updates"]);
    if (closeBeforeReply) backend.unsubscribeStreams(id);
    backend.acceptSharedResponse(id, { data: { subscription: { id: "daemon-sub" } } }, "");
    if (!closeBeforeReply) backend.unsubscribeStreams(id);
    assert.deepEqual(cancellations.map(call => call[2]), ["daemon-sub"]);
}

const sessions = source("qml/Shelllist/Io/DaemonSessions.qml");

// Execute the registry with bridge-addressed replies. The echoed route kind
// is authoritative even when local IDs resemble transport control IDs.
const registry = { sessions: {}, revision: 0 };
registry.registry = registry;
vm.createContext(registry);
vm.runInContext(sessions.match(/^    function [\s\S]*?^    }/gm).join("\n"), registry);
const routing = {};
vm.createContext(routing);
vm.runInContext(source("qml/Shelllist/Io/JsonlRouting.js").replace(/^\.pragma library\s*/, ""), routing);

for (const [kind, localId, ok] of [
    ["base-subscription", "session-subscribe", false],
    ["base-subscription", "different-base-id", false],
    ["base-subscription", "session-subscribe", true],
    ["subscription", "subscribe-1", false],
    ["subscription", "session-subscribe", false],
    ["call", "session-subscribe", false],
    ["control", "cancel-1", false]
]) {
    const responses = [];
    const recoveries = [];
    const failures = [];
    const subscriptions = [];
    const consumer = {
        active: true, streams: ["updates"],
        baseSubscriptionId: "", baseSubscriptionPending: kind === "base-subscription",
        backend: {
            acceptSharedResponse: (...args) => responses.push(args),
            failSharedTransport: message => failures.push(message)
        }
    };
    const transportId = registry.namespace("consumer-1", localId);
    const session = {
        daemonName: "test-daemon",
        consumers: { "consumer-1": consumer },
        generation: 0,
        subscriptionSequence: 0,
        client: {
            recover(message) {
                recoveries.push(message);
                registry.failSession("test-daemon", message);
            },
            subscribeExtra: (...args) => subscriptions.push(args)
        }
    };
    registry.sessions["test-daemon"] = session;
    const outcome = routing.responseOutcome({
        id: transportId, ok, error: "subscription refused",
        route: { consumerId: "consumer-1", localId, kind, generation: 0 },
        response: { data: { subscription: { id: "subscription-1" } } }
    }, "test-daemon");
    registry.routeResponse("test-daemon", outcome.id, outcome.envelope, outcome.error, outcome.route);
    assert.deepEqual(responses, [[localId, outcome.envelope, outcome.error]]);
    const shouldRecover = kind === "base-subscription" && !ok;
    assert.deepEqual(recoveries, shouldRecover ? ["subscription refused"] : [], `${kind}: ${localId}`);
    if (shouldRecover) {
        registry.restoreSubscriptions("test-daemon");
        assert.equal(subscriptions.length, 1);
    }
}

function subscriptionLifecycle() {
    const subscriptions = [], cancellations = [], responses = [], events = [];
    const view = {
        active: false, streams: ["battery.changed"],
        baseSubscriptionId: "", baseSubscriptionPending: false,
        backend: {
            acceptSharedResponse: (...args) => responses.push(args),
            acceptSharedEvent: event => events.push(event),
            failSharedTransport() {}
        }
    };
    const session = {
        daemonName: "test-daemon", subscriptionSequence: 0, generation: 0,
        consumers: {
            resident: { active: true, streams: [], baseSubscriptionId: "resident-sub",
                baseSubscriptionPending: false, backend: { failSharedTransport() {} } },
            view
        },
        client: {
            ready: true, active: true,
            subscribeExtra: (...args) => subscriptions.push(args),
            cancel: (...args) => cancellations.push(args),
            release() {}
        }
    };
    registry.sessions[session.daemonName] = session;
    return {
        session, view, subscriptions, cancellations, responses, events,
        open: () => registry.update(session.daemonName, "view", true, view.streams, true),
        close: () => registry.update(session.daemonName, "view", false, view.streams, true),
        reply: (index, id) => registry.routeResponse(session.daemonName, subscriptions[index][0],
            { ok: true, data: { subscription: { id } } }, "", subscriptions[index][2])
    };
}

// Reopening while Subscribe is pending adopts that request, rather than
// overwriting its route and orphaning a second daemon subscription.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    fixture.close();
    fixture.open();
    fixture.reply(0, "view-sub-1");
    fixture.close();
    fixture.open();
    fixture.reply(1, "view-sub-2");
    fixture.close();
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["view-sub-1", "view-sub-2"]);
}

// A reply while closed must be cancelled.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    fixture.close();
    fixture.reply(0, "closed-sub");
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["closed-sub"]);
}

// Destruction must also cancel late base and extra subscription replies.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    registry.subscribe("test-daemon", "view", "subscribe-extra", ["updates"], false);
    registry.detach("test-daemon", "view");
    assert.equal(fixture.session.client.active, true, "the resident bar keeps the bridge alive");
    fixture.reply(0, "detached-base");
    fixture.reply(1, "detached-extra");
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["detached-base", "detached-extra"]);
    assert.equal(fixture.responses.length, 0);
}

// A delayed response from a retired transport must not claim a new request.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    registry.failSession("test-daemon", "connection lost");
    // The resident consumer also resubscribes; find the new view request.
    registry.restoreSubscriptions("test-daemon");
    const nextIndex = fixture.subscriptions.findIndex(([id], index) => index > 0 && id.startsWith("view::"));
    fixture.reply(0, "old-generation");
    fixture.reply(nextIndex, "new-generation");
    fixture.close();
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["new-generation"]);
}

// Event ownership is supplied by Rust, not a QML subscription-ID dictionary.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    const event = { stream: "updates", subscription_id: "view-sub" };
    const route = fixture.subscriptions[0][2];
    registry.routeEvent("test-daemon", event, route);
    registry.routeEvent("test-daemon", event, { ...route, consumerId: "missing" });
    registry.routeEvent("test-daemon", event, null);
    registry.failSession("test-daemon", "restarted");
    registry.routeEvent("test-daemon", event, route);
    assert.deepEqual(fixture.events, [event], "only the owning view receives a current-generation event");
}

// Startup buffering is bounded, and closing/recovery fences late stdout.
{
    const client = { queuedLines: ["first"], maximumQueuedRequests: 1, ready: false,
        start() {}, retiring: true, handleMessage() { throw new Error("retired message delivered"); } };
    install(client, transport);
    assert.throws(() => client.send({ id: "overflow", op: "call" }), /capacity exceeded/);
    client.handleLine('{"kind":"response"}');
}

console.log("daemon boundary checks passed");
