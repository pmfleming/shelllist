pragma Singleton

import QtQuick
import "process"
import "SubscriptionCleanup.js" as Cleanup

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
            subscriptionSequence: 0,
            cleanupSequence: 0,
            owner: 0,
            resources: ({})
        };
        client.response.connect(function (id, envelope, transportError, route) {
            registry.routeResponse(daemonName, id, envelope, transportError, route);
        });
        if (client.requestUnsent) {
            client.requestUnsent.connect(function (id, message, route) {
                registry.routeUnsent(daemonName, id, message, route);
            });
        }
        if (client.ownerRetired)
            client.ownerRetired.connect(function () { registry.retireOwner(session); });
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
        if (consumerSequence >= 2147483647)
            throw new Error("UNSENT: consumer identity space exhausted");
        const id = "consumer-" + (++consumerSequence);
        reserveConsumer(session, id);
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
        const consumer = session.consumers[consumerId];
        consumer.detaching = true;
        consumer.active = false; // revoke event/new-work authority before notifying queued UNSENT
        Object.values(session.resources).filter(record => record.consumerId === consumerId).forEach(Cleanup.retireView);
        if (session.client.discardQueued)
            session.client.discardQueued(consumerId);
        const consumers = Object.assign({}, session.consumers);
        delete consumers[consumerId];
        session.consumers = consumers;
        pumpCleanup(session);
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
        if (!consumer.active) {
            if (session.client.discardQueued)
                session.client.discardQueued(consumerId);
            cancelBaseSubscription(session, consumerId, consumer);
        }
        updateSession(session);
        if (consumer.active && session.client.ready)
            ensureBaseSubscription(session, consumerId, consumer);
        revision += 1;
    }

    function updateSession(session) {
        session.client.active = Object.keys(session.consumers).some(function (id) {
            return session.consumers[id].active;
        }) || (session.client.ready && Object.values(session.resources).some(record => !record.wanted && record.state !== "uncertain"));
    }

    function isReady(daemonName) {
        const session = sessions[daemonName];
        return !!session && !!session.client.ready;
    }

    function reserveConsumer(session, consumerId) {
        const key = "release-" + consumerId + "-" + session.generation;
        if (!session.resources[key])
            Cleanup.reserve(session, key, consumerId, "", "release");
    }

    function requireAdmission(session, consumerId) {
        if (!session || !session.consumers[consumerId] || session.consumers[consumerId].detaching
                || session.client.lifecycle === "stopping" || session.client.retiring)
            throw new Error("UNSENT: shared owner is retiring; request cannot transfer to a replacement");
    }

    function call(daemonName, consumerId, localId, method, params) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        requireAdmission(session, consumerId);
        reserveConsumer(session, consumerId);
        session.client.call(namespace(consumerId, localId), method, params, address(session, consumerId, localId, "call"));
    }

    function cancel(daemonName, consumerId, requestId, cancellationId) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        requireAdmission(session, consumerId);
        const localId = cancellationId || ("cancel-" + requestId);
        session.client.cancel(namespace(consumerId, localId), requestId, address(session, consumerId, localId, "control"));
    }

    function subscribe(daemonName, consumerId, localId, streams, base) {
        const session = sessions[daemonName];
        if (!session)
            throw new Error("Shared daemon session is unavailable");
        requireAdmission(session, consumerId);
        if (!Number.isSafeInteger(session.subscriptionSequence) || session.subscriptionSequence >= Number.MAX_SAFE_INTEGER)
            throw new Error("UNSENT: subscription identity space exhausted");
        reserveConsumer(session, consumerId);
        const transportLocalId = localId + "::" + (++session.subscriptionSequence);
        const transportId = namespace(consumerId, transportLocalId);
        const backend = session.consumers[consumerId].backend;
        const protocol = backend.expectedProtocol || "";
        if (typeof protocol !== "string" || protocol.length > 128)
            throw new Error("UNSENT: invalid subscription receipt identity reservation");
        const record = Cleanup.reserve(session, transportId, consumerId, localId, base ? "base-subscription" : "subscription");
        record.protocol = protocol;
        record.version = backend.expectedVersion || 0;
        if (base)
            session.consumers[consumerId].baseSubscriptionRequestId = transportId;
        try {
            session.client.subscribeExtra(transportId, streams || [], address(session, consumerId, localId, base ? "base-subscription" : "subscription"));
        } catch (error) {
            if (Cleanup.definiteUnsent(error))
                delete session.resources[transportId];
            else if (session.resources[transportId] === record) {
                record.state = "uncertain"; // an unclassified bridge write exception is not UNSENT
                record.wanted = false;
            }
            throw error;
        }
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
            if (Cleanup.definiteUnsent(error))
                consumer.backend.acceptSharedUnsent("session-subscribe", String(error));
            else
                consumer.backend.acceptSharedResponse("session-subscribe", null, "Subscription dispatch outcome unknown: " + error);
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
        cancelBaseSubscription(session, consumerId, consumer);
        ensureBaseSubscription(session, consumerId, consumer);
        return true;
    }

    function cancelBaseSubscription(session, consumerId, consumer) {
        // A reopen adopts a pending request. If its reply arrives while closed,
        // recordSubscription cancels the daemon-issued ID instead.
        if (!consumer.baseSubscriptionId)
            return;
        unsubscribe(session.daemonName, consumerId, "session-subscribe");
        consumer.baseSubscriptionId = "";
        consumer.baseSubscriptionRequestId = "";
    }

    function subscriptionId(envelope) {
        const subscription = envelope && envelope.data ? (envelope.data.subscription || ({})) : ({});
        return subscription.id || "";
    }

    function ownsSubscription(daemonName, consumerId, localId, nativeId) {
        const session = sessions[daemonName];
        const record = session ? Cleanup.find(session, consumerId, localId) : null;
        return !!record && record.owner === session.owner && record.generation === session.generation
            && record.state === "live" && record.nativeId === nativeId;
    }

    function unsubscribe(daemonName, consumerId, localId) {
        const session = sessions[daemonName];
        const record = session ? Cleanup.find(session, consumerId, localId) : null;
        if (!record)
            return false;
        Cleanup.retireView(record);
        pumpCleanup(session);
        return true;
    }

    function pumpCleanup(session) {
        if (!session.client.ready || session.client.lifecycle === "stopping" || session.client.retiring)
            return;
        const record = Cleanup.next(session);
        if (!record)
            return;
        if (!Number.isSafeInteger(session.cleanupSequence) || session.cleanupSequence >= Number.MAX_SAFE_INTEGER)
            return; // keep bounded responsibility; never alias a previous cleanup attempt
        const localId = "cleanup-" + (++session.cleanupSequence);
        record.controlId = namespace(record.consumerId, localId);
        record.state = "sending"; // reserve before a synchronous response/UNSENT
        const route = Object.assign(address(session, record.consumerId, localId, "control"), {generation: record.generation});
        try {
            if (record.kind === "release")
                session.client.release(record.controlId, route, true);
            else
                session.client.cancel(record.controlId, record.nativeId, route, true);
        } catch (error) {
            if (Cleanup.definiteUnsent(error)) {
                record.state = "cleanup"; // definite local never-written; exact resource retained
                record.controlId = "";
            } else {
                record.state = "uncertain"; // keep exact attempt identity for a possible late acknowledgement
            }
        }
    }

    function recordSubscription(session, transportId, route, consumer, envelope, transportError) {
        const record = session.resources[transportId];
        if (!Cleanup.matches(record, route) || record.owner !== session.owner
                || (record.state !== "pending" && record.state !== "uncertain"))
            return false;
        const late = record.state === "uncertain";
        const valid = Cleanup.subscriptionReceipt(record, envelope, transportError);
        if (late && (!valid || record.nativeId))
            return false;
        const base = route.kind === "base-subscription";
        const current = consumer && (!base || transportId === consumer.baseSubscriptionRequestId);
        if (base && current)
            consumer.baseSubscriptionPending = false;
        if (!valid) {
            record.state = "uncertain"; // rejected/invalid data grants no native ID authority
            return !!current;
        }
        if (late)
            record.wanted = false; // late acknowledgement owns cleanup only, never a reopened view
        record.nativeId = registry.subscriptionId(envelope);
        record.state = "live";
        if (!current || !consumer.active || !record.wanted)
            Cleanup.retireView(record);
        if (base && current && record.wanted)
            consumer.baseSubscriptionId = record.nativeId;
        if (!record.wanted)
            pumpCleanup(session);
        return !!current && !late; // backend may retire its pending window, not regain event authority
    }

    function cleanupRecord(session, transportId, route) {
        return route.kind === "control" ? Object.values(session.resources).find(row => row.controlId === transportId
            && row.owner === session.owner && row.generation === route.generation
            && row.consumerId === route.consumerId && namespace(route.consumerId, route.localId) === transportId) : null;
    }

    function routeUnsent(daemonName, transportId, message, route) {
        const session = sessions[daemonName];
        if (!session || !route)
            return;
        const cleanup = cleanupRecord(session, transportId, route);
        if (cleanup) {
            const record = cleanup;
            if (record.state === "sending") {
                record.state = "cleanup";
                record.controlId = "";
            }
            return;
        }
        if (route.kind === "base-subscription" || route.kind === "subscription") {
            if (!Cleanup.matches(session.resources[transportId], route) || session.resources[transportId].owner !== session.owner
                    || session.resources[transportId].state !== "pending")
                return;
            delete session.resources[transportId]; // definitely no resource was admitted
        }
        const consumer = route.generation === session.generation ? session.consumers[route.consumerId] : null;
        if (!consumer)
            return;
        if (route.kind === "base-subscription") {
            if (!consumer.baseSubscriptionPending || consumer.baseSubscriptionRequestId !== transportId)
                return;
            consumer.baseSubscriptionPending = false;
            consumer.baseSubscriptionRequestId = "";
        }
        consumer.backend.acceptSharedUnsent(route.localId, message);
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
        const cleanup = cleanupRecord(session, transportId, route);
        if (cleanup) {
            const record = cleanup;
            if (record.state === "sending" || record.state === "uncertain") {
                Cleanup.complete(session, record, envelope, transportError);
                pumpCleanup(session);
                updateSession(session);
            }
            return;
        }
        const consumer = route.generation === session.generation ? session.consumers[route.consumerId] : null;
        if ((route.kind === "base-subscription" || route.kind === "subscription")
                && !recordSubscription(session, transportId, route, consumer, envelope, transportError))
            return;
        if (consumer) {
            const record = session.resources[transportId];
            if ((route.kind === "base-subscription" || route.kind === "subscription") && record?.state === "uncertain" && !transportError)
                transportError = "Invalid subscription acknowledgement; outcome unknown";
            consumer.backend.acceptSharedResponse(route.localId, envelope, transportError);
        }
    }

    function routeEvent(daemonName, event, route) {
        const session = sessions[daemonName];
        if (!session)
            return;
        if (!route) {
            if (event.subscription_id)
                return;
            Object.keys(session.consumers).forEach(function (id) {
                const consumer = session.consumers[id];
                if (consumer.active && consumer.streams.indexOf(event.stream) >= 0)
                    consumer.backend.acceptSharedEvent(event);
            });
            return;
        }
        if (route.generation !== session.generation)
            return;
        const consumer = session.consumers[route.consumerId];
        if (!consumer)
            return;
        if (route.kind === "base-subscription" && (!consumer.active
                || !consumer.baseSubscriptionId
                || (event.subscription_id || event.request_id) !== consumer.baseSubscriptionId))
            return;
        if (route.kind === "subscription") {
            const record = Cleanup.find(session, route.consumerId, route.localId);
            if (!consumer.active || !record || record.state !== "live"
                    || (event.subscription_id || event.request_id) !== record.nativeId)
                return;
        }
        consumer.backend.acceptSharedEvent(event);
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

    property Timer cleanupProgress: Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: Object.values(registry.sessions).forEach(session => registry.pumpCleanup(session))
    }

    function retireOwner(session) {
        session.owner += 1;
        session.generation += 1;
        session.resources = ({}); // only actual physical exit ends resource responsibility
        Object.keys(session.consumers).forEach(id => {
            reserveConsumer(session, id);
            const consumer = session.consumers[id];
            consumer.baseSubscriptionId = "";
            consumer.baseSubscriptionRequestId = "";
            consumer.baseSubscriptionPending = false;
        });
    }

    function failSession(daemonName, message) {
        const session = sessions[daemonName];
        if (!session)
            return;
        // Failure retires view authority, not native resources. Some protocol
        // failures intentionally leave the physical client alive. Exact cleanup
        // stays on its captured route/owner until ownerRetired proves exit.
        session.generation += 1;
        Object.values(session.resources).forEach(Cleanup.retireView);
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
