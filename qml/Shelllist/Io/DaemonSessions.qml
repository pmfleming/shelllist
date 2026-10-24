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

    function address(session, consumerId, localId, kind) {
        return {
            consumerId: consumerId,
            localId: localId,
            kind: kind,
            generation: session.generation
        };
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
            generation: 0,
            subscriptionSequence: 0
        };
        client.response.connect(function (id, envelope, transportError, route) {
            registry.routeResponse(daemonName, id, envelope, transportError, route);
        });
        client.eventReceived.connect(function (event, route) {
            registry.routeEvent(daemonName, event, route);
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
        return sessions[daemonName] || createSession(daemonName, recoverProtocolErrors);
    }

    function attach(backend) {
        const session = sessionFor(backend.daemonName, backend.recoverProtocolErrors);
        const id = "consumer-" + (++consumerSequence);
        // Only live view handles remain in QML. Copy on change rather than
        // churning properties on a long-lived QV4 object.
        const consumers = Object.assign({}, session.consumers);
        consumers[id] = {
            backend: backend,
            active: !!backend.active,
            streams: (backend.streams || []).slice(),
            baseSubscriptionId: "",
            baseSubscriptionRequestId: "",
            baseSubscriptionPending: false
        };
        session.consumers = consumers;
        updateSession(session);
        if (consumers[id].active && session.client.ready)
            ensureBaseSubscription(session, id, consumers[id]);
        revision += 1;
        return id;
    }

    function detach(daemonName, consumerId) {
        const session = sessions[daemonName];
        if (!session || !session.consumers[consumerId])
            return;
        // The bridge owns the subscription-ID index. Late subscribe replies
        // still carry their address and are cancelled below if this view is gone.
        session.client.release(namespace(consumerId, "cancel-detached"), address(session, consumerId, "cancel-detached", "control"));
        const consumers = Object.assign({}, session.consumers);
        delete consumers[consumerId];
        session.consumers = consumers;
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
        session.client.call(namespace(consumerId, localId), method, params, address(session, consumerId, localId, "call"));
    }

    function cancel(daemonName, consumerId, requestId, cancellationId) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        const localId = cancellationId || ("cancel-" + requestId);
        session.client.cancel(namespace(consumerId, localId), requestId, address(session, consumerId, localId, "control"));
    }

    function subscribe(daemonName, consumerId, localId, streams, base) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        const transportLocalId = base ? localId + "::" + (++session.subscriptionSequence) : localId;
        const transportId = namespace(consumerId, transportLocalId);
        if (base)
            session.consumers[consumerId].baseSubscriptionRequestId = transportId;
        session.client.subscribeExtra(transportId, streams || [], address(session, consumerId, localId, base ? "base-subscription" : "subscription"));
    }

    function ensureBaseSubscription(session, consumerId, consumer) {
        if (consumer.baseSubscriptionId || consumer.baseSubscriptionPending)
            return;
        consumer.baseSubscriptionPending = true;
        try {
            subscribe(session.daemonName, consumerId, "session-subscribe", consumer.streams, true);
        } catch (error) {
            consumer.baseSubscriptionPending = false;
            consumer.baseSubscriptionRequestId = "";
            session.client.recover("Could not establish subscription: " + error);
        }
    }

    // A delta gap needs a fresh baseline, not a new connection. Cancel only
    // this consumer's subscription; operations and other consumers stay owned.
    function renewBaseSubscription(daemonName, consumerId) {
        const session = sessions[daemonName];
        const consumer = session ? session.consumers[consumerId] : null;
        if (!consumer || !consumer.active || !session.client.ready)
            return false;
        if (consumer.baseSubscriptionPending)
            return true;
        try {
            cancelBaseSubscription(session, consumerId, consumer);
            ensureBaseSubscription(session, consumerId, consumer);
        } catch (error) {
            // Control uncertainty must not leave an unbounded orphan stream.
            // Retirement cancels ownership; no effect is replayed.
            session.client.recover("Could not retire subscription: " + error);
            return false;
        }
        return true;
    }

    function cancelBaseSubscription(session, consumerId, consumer) {
        // A reopen adopts a pending request. If its reply arrives while closed,
        // recordSubscription cancels the daemon-issued ID instead.
        if (!consumer.baseSubscriptionId)
            return;
        const subscriptionId = consumer.baseSubscriptionId;
        consumer.baseSubscriptionId = "";
        consumer.baseSubscriptionRequestId = "";
        cancel(session.daemonName, consumerId, subscriptionId, "cancel-session-subscription");
    }

    function subscriptionId(envelope) {
        const subscription = envelope && envelope.data ? (envelope.data.subscription || ({})) : ({});
        return subscription.id || "";
    }

    function recordSubscription(session, transportId, route, consumer, envelope, transportError) {
        if (route.kind !== "base-subscription")
            return true;
        const id = registry.subscriptionId(envelope);
        // Renewal starts only after the preceding reply was adopted/cancelled.
        // A mismatched reply is therefore retired/duplicate, not a new owner.
        if (transportId !== consumer.baseSubscriptionRequestId)
            return false;
        // Duplicate replies must not adopt or cancel a newer subscription.
        if (!consumer.baseSubscriptionPending)
            return false;
        consumer.baseSubscriptionPending = false;
        if (!id)
            return true;
        if (consumer.active && !transportError)
            consumer.baseSubscriptionId = id;
        else
            cancel(session.daemonName, route.consumerId, id, "cancel-stale-subscription");
        return true;
    }

    function routeResponse(daemonName, transportId, envelope, transportError, route) {
        const session = sessions[daemonName];
        if (!session)
            return;
        if (!route) {
            // Never fall back to the crashing per-request dictionary or infer a
            // route kind from a local ID. Shared clients must be upgraded together.
            if (transportId.indexOf("::") >= 0)
                session.client.recover("" + daemonName + " client lacks routed replies; rebuild the Rust daemon clients");
            return;
        }
        if (route.generation !== session.generation)
            return;
        const consumer = session.consumers[route.consumerId];
        if (!consumer) {
            if (route.kind === "base-subscription" || route.kind === "subscription") {
                const id = registry.subscriptionId(envelope);
                if (id)
                    cancel(daemonName, route.consumerId, id, "cancel-detached-" + id);
            }
            return;
        }
        if (!recordSubscription(session, transportId, route, consumer, envelope, transportError))
            return;
        consumer.backend.acceptSharedResponse(route.localId, envelope, transportError);
        if (route.kind === "base-subscription" && transportError)
            session.client.recover(transportError);
    }

    function routeEvent(daemonName, event, route) {
        const session = sessions[daemonName];
        if (!session)
            return;
        if (route) {
            if (route.generation !== session.generation)
                return;
            const consumer = session.consumers[route.consumerId];
            if (consumer) {
                if (route.kind === "base-subscription" && (!consumer.active
                        || !consumer.baseSubscriptionId
                        || (event.subscription_id || event.request_id) !== consumer.baseSubscriptionId))
                    return;
                consumer.backend.acceptSharedEvent(event);
            }
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
            consumer.baseSubscriptionRequestId = "";
            consumer.baseSubscriptionPending = false;
            if (consumer.active)
                ensureBaseSubscription(session, id, consumer);
        });
    }

    function failSession(daemonName, message) {
        const session = sessions[daemonName];
        if (!session)
            return;
        session.generation += 1;
        Object.keys(session.consumers).forEach(function (id) {
            const consumer = session.consumers[id];
            consumer.baseSubscriptionId = "";
            consumer.baseSubscriptionRequestId = "";
            consumer.baseSubscriptionPending = false;
            consumer.backend.failSharedTransport(message);
        });
        revision += 1;
    }
}
