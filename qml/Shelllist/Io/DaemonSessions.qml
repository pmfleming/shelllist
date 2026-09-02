pragma Singleton

import QtQuick
import "process"

QtObject {
    id: registry

    property int revision: 0
    property int consumerSequence: 0
    property var sessions: ({})

    property Component clientFactory: Component {
        JsonlDaemonClient {
            automaticSubscribe: false
        }
    }

    function namespace(consumerId, localId) {
        return consumerId + "::" + localId;
    }

    function createSession(daemonName, recoverProtocolErrors) {
        const client = clientFactory.createObject(null, {
            daemonName: daemonName,
            streams: [],
            active: false,
            recoverProtocolErrors: recoverProtocolErrors
        });
        if (!client)
            throw new Error("Could not create shared daemon session for " + daemonName);
        const session = {
            daemonName: daemonName,
            client: client,
            consumers: ({}),
            routes: ({}),
            subscriptionOwners: ({})
        };
        client.response.connect(function (id, envelope, transportError) {
            registry.routeResponse(daemonName, id, envelope, transportError);
        });
        client.eventReceived.connect(function (event) {
            registry.routeEvent(daemonName, event);
        });
        client.transportFailed.connect(function (message) {
            registry.failSession(daemonName, message);
        });
        client.readyChanged.connect(function () {
            registry.revision += 1;
            if (client.ready)
                registry.restoreSubscriptions(daemonName);
        });
        const next = Object.assign({}, sessions);
        next[daemonName] = session;
        sessions = next;
        return session;
    }

    function sessionFor(daemonName, recoverProtocolErrors) {
        const current = sessions[daemonName];
        if (current)
            return current;
        return createSession(daemonName, recoverProtocolErrors);
    }

    function attach(backend) {
        const session = sessionFor(backend.daemonName, backend.recoverProtocolErrors);
        const id = "consumer-" + (++consumerSequence);
        session.consumers[id] = {
            backend: backend,
            active: !!backend.active,
            streams: (backend.streams || []).slice(),
            baseSubscriptionId: "",
            baseSubscriptionPending: false
        };
        updateSession(session);
        revision += 1;
        return id;
    }

    function detach(daemonName, consumerId) {
        const session = sessions[daemonName];
        if (!session || !session.consumers[consumerId])
            return;
        cancelOwnedSubscriptions(session, consumerId);
        delete session.consumers[consumerId];
        Object.keys(session.routes).forEach(function (id) {
            if (session.routes[id].consumerId === consumerId)
                delete session.routes[id];
        });
        updateSession(session);
        revision += 1;
    }

    function update(daemonName, consumerId, active, streams, recoverProtocolErrors) {
        const session = sessions[daemonName];
        if (!session || !session.consumers[consumerId])
            return;
        const consumer = session.consumers[consumerId];
        consumer.active = !!active;
        consumer.streams = (streams || []).slice();
        session.client.recoverProtocolErrors = recoverProtocolErrors;
        if (!consumer.active)
            cancelBaseSubscription(session, consumerId, consumer);
        updateSession(session);
        if (consumer.active && session.client.ready)
            ensureBaseSubscription(session, consumerId, consumer);
        revision += 1;
    }

    function updateSession(session) {
        session.client.active = Object.keys(session.consumers).some(function (id) {
            return session.consumers[id].active;
        });
    }

    function isReady(daemonName) {
        const session = sessions[daemonName];
        return !!session && !!session.client.ready;
    }

    function call(daemonName, consumerId, localId, method, params) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        const id = namespace(consumerId, localId);
        session.routes[id] = { consumerId: consumerId, localId: localId, kind: "call" };
        session.client.call(id, method, params);
    }

    function cancel(daemonName, consumerId, requestId, cancellationId) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        delete session.subscriptionOwners[requestId];
        const localId = cancellationId || ("cancel-" + requestId);
        const id = namespace(consumerId, localId);
        session.routes[id] = { consumerId: consumerId, localId: localId, kind: "control" };
        session.client.cancel(id, requestId);
    }

    function subscribe(daemonName, consumerId, localId, streams, base) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        const id = namespace(consumerId, localId);
        session.routes[id] = {
            consumerId: consumerId,
            localId: localId,
            kind: base ? "base-subscription" : "subscription"
        };
        session.client.subscribeExtra(id, streams || []);
    }

    function ensureBaseSubscription(session, consumerId, consumer) {
        if (consumer.baseSubscriptionId || consumer.baseSubscriptionPending)
            return;
        consumer.baseSubscriptionPending = true;
        subscribe(session.daemonName, consumerId, "session-subscribe", consumer.streams, true);
    }

    function cancelBaseSubscription(session, consumerId, consumer) {
        consumer.baseSubscriptionPending = false;
        if (!consumer.baseSubscriptionId)
            return;
        const subscriptionId = consumer.baseSubscriptionId;
        consumer.baseSubscriptionId = "";
        delete session.subscriptionOwners[subscriptionId];
        session.client.cancel(namespace(consumerId, "cancel-session-subscription"), subscriptionId);
    }

    function cancelOwnedSubscriptions(session, consumerId) {
        Object.keys(session.subscriptionOwners).forEach(function (subscriptionId) {
            if (session.subscriptionOwners[subscriptionId] !== consumerId)
                return;
            delete session.subscriptionOwners[subscriptionId];
            session.client.cancel(namespace(consumerId, "cancel-detached-" + subscriptionId), subscriptionId);
        });
    }

    function subscriptionId(envelope) {
        const subscription = envelope && envelope.data ? (envelope.data.subscription || ({})) : ({});
        return subscription.id || "";
    }

    function recordSubscription(session, route, consumer, envelope, transportError) {
        const id = registry.subscriptionId(envelope);
        if (route.kind === "subscription") {
            if (id)
                session.subscriptionOwners[id] = route.consumerId;
            return;
        }
        if (route.kind !== "base-subscription")
            return;
        consumer.baseSubscriptionPending = false;
        if (!id)
            return;
        if (consumer.active && !transportError) {
            consumer.baseSubscriptionId = id;
            session.subscriptionOwners[id] = route.consumerId;
        } else {
            session.client.cancel(namespace(route.consumerId, "cancel-stale-subscription"), id);
        }
    }

    function routeResponse(daemonName, transportId, envelope, transportError) {
        const session = sessions[daemonName];
        if (!session)
            return;
        const route = session.routes[transportId];
        if (!route)
            return;
        delete session.routes[transportId];
        const consumer = session.consumers[route.consumerId];
        if (!consumer)
            return;
        recordSubscription(session, route, consumer, envelope, transportError);
        consumer.backend.acceptSharedResponse(route.localId, envelope, transportError);
    }

    function routeEvent(daemonName, event) {
        const session = sessions[daemonName];
        if (!session)
            return;
        const owner = session.subscriptionOwners[event.subscription_id || ""];
        if (owner && session.consumers[owner]) {
            session.consumers[owner].backend.acceptSharedEvent(event);
            return;
        }
        if (event.subscription_id)
            return;
        Object.keys(session.consumers).forEach(function (id) {
            const consumer = session.consumers[id];
            if (consumer.active && consumer.streams.indexOf(event.stream) >= 0)
                consumer.backend.acceptSharedEvent(event);
        });
    }

    function restoreSubscriptions(daemonName) {
        const session = sessions[daemonName];
        if (!session)
            return;
        Object.keys(session.consumers).forEach(function (id) {
            const consumer = session.consumers[id];
            consumer.baseSubscriptionId = "";
            consumer.baseSubscriptionPending = false;
            if (consumer.active)
                ensureBaseSubscription(session, id, consumer);
        });
    }

    function failSession(daemonName, message) {
        const session = sessions[daemonName];
        if (!session)
            return;
        session.routes = ({});
        session.subscriptionOwners = ({});
        Object.keys(session.consumers).forEach(function (id) {
            const consumer = session.consumers[id];
            consumer.baseSubscriptionId = "";
            consumer.baseSubscriptionPending = false;
            consumer.backend.failSharedTransport(message);
        });
        revision += 1;
    }
}
