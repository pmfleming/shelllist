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

const transport = source("qml/Shelllist/Io/process/JsonlDaemonClient.qml");
function clearsQueue(block) {
    return /(?:queuedLines\s*=\s*\[\]|clearQueue\(\))/.test(block);
}

const startFailure = transport.match(/catch \(error\) \{[\s\S]*?Could not start/);
if (!startFailure || !clearsQueue(startFailure[0]))
    throw new Error("daemon start failure does not retire queued requests");
const exitHandler = transport.match(/onExited:[\s\S]*?\n\s*\}/);
if (!exitHandler || !clearsQueue(exitHandler[0]))
    throw new Error("daemon exit does not retire queued requests");
if (!/environment:\s*\(\{\s*TOKIO_WORKER_THREADS:\s*"1"\s*\}\)/.test(transport))
    throw new Error("daemon bridge clients are not constrained to one Tokio worker");

const backend = source("qml/Shelllist/Io/DaemonBackend.qml");
for (const token of ["property var endpoint", "property string expectedProtocol",
        "property int expectedVersion", "function acceptEvent",
        "ApiEnvelope.compatibilityError", "function acceptSharedEvent",
        "DaemonSessions.attach(backend)"]) {
    if (!backend.includes(token))
        throw new Error(`DaemonBackend is missing boundary token: ${token}`);
}

const sessions = source("qml/Shelllist/Io/DaemonSessions.qml");
for (const token of ["property var sessions", "clientFactory.createObject",
        "function namespace", "function routeResponse", "function routeEvent"]) {
    if (!sessions.includes(token))
        throw new Error(`shared daemon session registry is missing boundary token: ${token}`);
}
if (/JsonlDaemonClient\s*\{/.test(backend))
    throw new Error("DaemonBackend still owns a per-consumer bridge process");

const adapters = [
    "launcher/ApplicationBackend.qml",
    "wifi/WifiBackend.qml",
    "bluetooth/BluetoothBackend.qml",
    "clipboard/ClipboardBackend.qml",
    "bar/BarBackend.qml",
    "activity/ActivityBackend.qml",
    "battery/BatteryBackend.qml",
    "battery/BatteryEnergyBackend.qml"
];
for (const adapter of adapters) {
    const text = source(adapter);
    const endpoint = /endpoint\s*:/.test(text);
    const explicitIdentity = /expectedProtocol\s*:/.test(text)
        && /expectedVersion\s*:/.test(text);
    if (!endpoint && !explicitIdentity)
        throw new Error(`${adapter} does not declare its daemon API identity`);
}

for (const adapter of ["activity/ActivityBackend.qml", "battery/BatteryBackend.qml"]) {
    if (!/active:\s*controller\.uiActive/.test(source(adapter)))
        throw new Error(`${adapter} keeps a duplicate permanent bar transport`);
}

// Execute the registry's JavaScript routing with a fake transport. Keep the
// recorded route kind authoritative, even when local IDs resemble controls.
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
        routes: { [transportId]: { consumerId: "consumer-1", localId, kind } },
        subscriptionOwners: {},
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
        response: { data: { subscription: { id: "subscription-1" } } }
    }, "test-daemon");
    registry.routeResponse("test-daemon", outcome.id, outcome.envelope, outcome.error);
    assert.deepEqual(responses, [[localId, outcome.envelope, outcome.error]]);
    assert.equal(session.routes[transportId], undefined);
    const shouldRecover = kind === "base-subscription" && !ok;
    assert.deepEqual(recoveries, shouldRecover ? ["subscription refused"] : [], `${kind}: ${localId}`);
    assert.deepEqual(failures, recoveries);
    if (kind === "base-subscription") {
        assert.equal(consumer.baseSubscriptionPending, false);
        assert.equal(consumer.baseSubscriptionId, ok ? "subscription-1" : "");
    }
    if (shouldRecover) {
        assert.equal(Object.keys(session.subscriptionOwners).length, 0);
        registry.restoreSubscriptions("test-daemon");
        assert.equal(subscriptions.length, 1);
        assert.equal(subscriptions[0][0], "consumer-1::session-subscribe::1");
        assert.equal(consumer.baseSubscriptionPending, true);
    }
}

function subscriptionLifecycle() {
    const subscriptions = [], cancellations = [], responses = [];
    const view = {
        active: false, streams: ["battery.changed"],
        baseSubscriptionId: "", baseSubscriptionPending: false,
        backend: {
            acceptSharedResponse: (...args) => responses.push(args),
            failSharedTransport() {}
        }
    };
    const session = {
        daemonName: "test-daemon", subscriptionSequence: 0,
        consumers: {
            resident: { active: true, streams: [], baseSubscriptionId: "resident-sub",
                baseSubscriptionPending: false, backend: { failSharedTransport() {} } },
            view
        },
        routes: {}, subscriptionOwners: { "resident-sub": "resident" },
        client: {
            ready: true, active: true,
            subscribeExtra: (...args) => subscriptions.push(args),
            cancel: (...args) => cancellations.push(args)
        }
    };
    registry.sessions[session.daemonName] = session;
    return {
        session, view, subscriptions, cancellations, responses,
        open: () => registry.update(session.daemonName, "view", true, view.streams, true),
        close: () => registry.update(session.daemonName, "view", false, view.streams, true),
        reply: (index, id) => registry.routeResponse(session.daemonName, subscriptions[index][0],
            { ok: true, data: { subscription: { id } } }, "")
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
    assert.equal(Object.keys(fixture.session.routes).length, 0);
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

console.log("daemon boundary checks passed");
