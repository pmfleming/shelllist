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
for (const failure of ["start", "exit"]) {
    const writes = [], failures = [];
    const client = { active: true, ready: false, daemonName: "test-daemon",
        queuedLines: ["destructive-effect"], counters: { retryAttempt: 0 },
        initialRetryInterval: 1500, maximumRetryInterval: 30000,
        console: quietConsole, processError: { text: "crashed" },
        process: { running: false, exec() { throw new Error("start failed"); }, write: line => writes.push(line) },
        retryTimer: { running: false, restart() { this.running = true; } },
        transportFailed: message => failures.push(message) };
    client.client = client;
    install(client, transport);
    if (failure === "start") client.start();
    else {
        const body = transport.match(/onExited: function \(exitCode\) \{[^\n]*\n([\s\S]*?)\n        \}/)[1];
        vm.runInContext("function exited(exitCode) {" + body + "\n}", client);
        client.exited(1);
    }
    client.ready = true;
    client.flushQueue();
    assert.deepEqual(writes, [], `${failure}: failed-generation effects must never replay`);
    assert.equal(failures.length, 1);
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
    assert.equal(session.routes, undefined);
    const shouldRecover = kind === "base-subscription" && !ok;
    assert.deepEqual(recoveries, shouldRecover ? ["subscription refused"] : [], `${kind}: ${localId}`);
    assert.deepEqual(failures, recoveries);
    if (kind === "base-subscription") {
        assert.equal(consumer.baseSubscriptionPending, false);
        assert.equal(consumer.baseSubscriptionId, ok ? "subscription-1" : "");
    }
    if (shouldRecover) {
        assert.equal(session.subscriptionOwners, undefined);
        assert.equal(session.generation, 1);
        registry.restoreSubscriptions("test-daemon");
        assert.equal(subscriptions.length, 1);
        assert.equal(subscriptions[0][0], "consumer-1::session-subscribe::1");
        assert.equal(consumer.baseSubscriptionPending, true);
    }
}

function subscriptionLifecycle() {
    const subscriptions = [], cancellations = [], releases = [], responses = [], events = [];
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
            release: (...args) => releases.push(args)
        }
    };
    registry.sessions[session.daemonName] = session;
    return {
        session, view, subscriptions, cancellations, releases, responses, events,
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
    assert.equal(fixture.view.baseSubscriptionPending, true);
    fixture.open();
    assert.equal(fixture.subscriptions.length, 1);
    fixture.reply(0, "view-sub-1");
    assert.equal(fixture.view.baseSubscriptionId, "view-sub-1");
    assert.equal(fixture.responses[0][0], "session-subscribe");
    fixture.close();
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["view-sub-1"]);
    fixture.open();
    assert.notEqual(fixture.subscriptions[0][0], fixture.subscriptions[1][0]);
    fixture.reply(1, "view-sub-2");
    fixture.close();
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["view-sub-1", "view-sub-2"]);
}

// A reply while closed must be cancelled, and a later open starts afresh.
{
    const fixture = subscriptionLifecycle();
    fixture.open();
    fixture.close();
    fixture.reply(0, "closed-sub");
    assert.equal(fixture.view.baseSubscriptionPending, false);
    assert.equal(fixture.view.baseSubscriptionId, "");
    assert.deepEqual(fixture.cancellations.map(([, id]) => id), ["closed-sub"]);
    fixture.open();
    assert.equal(fixture.subscriptions.length, 2);
    assert.notEqual(fixture.subscriptions[0][0], fixture.subscriptions[1][0]);
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
    assert.equal(fixture.session.routes, undefined);
    assert.equal(fixture.releases.length, 1);
    assert.equal(fixture.releases[0][1].consumerId, "view");
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
    assert.notEqual(fixture.subscriptions[0][0], fixture.subscriptions[nextIndex][0]);
    fixture.reply(0, "old-generation");
    assert.equal(fixture.view.baseSubscriptionPending, true);
    assert.equal(fixture.view.baseSubscriptionId, "");
    fixture.reply(nextIndex, "new-generation");
    assert.equal(fixture.view.baseSubscriptionId, "new-generation");
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
    assert.deepEqual(fixture.events, [event]);
    registry.routeEvent("test-daemon", event, { ...route, consumerId: "missing" });
    registry.routeEvent("test-daemon", event, null);
    registry.failSession("test-daemon", "restarted");
    registry.routeEvent("test-daemon", event, route);
    assert.equal(fixture.events.length, 1, "unknown, unaddressed and retired events must not leak to another view");
}

// Startup buffering is bounded, and closing/recovery fences late stdout.
{
    const client = { queuedLines: ["first"], maximumQueuedRequests: 1, ready: false,
        start() {}, retiring: true, handleMessage() { throw new Error("retired message delivered"); } };
    install(client, transport);
    assert.throws(() => client.send({ id: "overflow", op: "call" }), /capacity exceeded/);
    assert.deepEqual(client.queuedLines, ["first"]);
    client.handleLine('{"kind":"response"}');
}

console.log("daemon boundary checks passed");
