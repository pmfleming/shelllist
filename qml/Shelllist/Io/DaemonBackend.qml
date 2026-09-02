import QtQuick
import Shelllist.Core as Core

Item {
    id: backend

    required property string daemonName
    required property string expectedProtocol
    required property int expectedVersion
    required property var streams
    required property bool active
    property bool recoverProtocolErrors: true
    property var pending: ({})
    property int requestSequence: 0
    property int subscriptionSequence: 0
    property string sharedConsumerId: ""

    readonly property bool requestRunning: pendingCount > 0
    readonly property int pendingCount: Object.keys(pending).length
    readonly property bool ready: {
        DaemonSessions.revision;
        return DaemonSessions.isReady(daemonName);
    }

    // Subscription ids returned by on-demand subscribe requests, keyed by the
    // request id that asked for them.
    property var extraSubscriptions: ({})
    // Subscribe replies are asynchronous. A view can close before its reply;
    // remember that intent so the eventual subscription is cancelled rather
    // than becoming an orphan that keeps daemon work alive.
    property var extraSubscriptionCancellations: ({})

    signal responseReceived(string id, var envelope, string transportError)
    signal eventReceived(var event)
    signal eventGapDetected(string stream, var event)
    signal transportFailed(string message, var lostRequestIds)
    signal transportReady
    signal sendFailed(string id, string message)

    function isPending(id: string): bool { return !!pending[id]; }

    function nextRequestId(prefix: string): string {
        requestSequence += 1;
        return prefix + "-" + requestSequence;
    }

    function callSequenced(prefix: string, method: string, params: var): bool {
        return call(nextRequestId(prefix), method, params || ({}));
    }

    function responseError(envelope: var, transportError: string,
            fallbackMessage: string): string {
        return Core.ApiEnvelope.responseError(envelope, transportError,
            expectedProtocol, expectedVersion, daemonName, fallbackMessage);
    }

    function routeEvent(event: var, handlers: var): bool {
        const handler = handlers ? handlers[event.stream] : null;
        if (!handler)
            return false;
        handler(event);
        return true;
    }

    function setPending(id: string, value: bool): void {
        const next = Object.assign({}, pending);
        if (value)
            next[id] = true;
        else
            delete next[id];
        pending = next;
    }

    function call(id: string, method: string, params: var): bool {
        if (isPending(id)) {
            console.warn("shelllist " + daemonName + " request rejected id=" + id + " reason=already-pending");
            return false;
        }
        setPending(id, true);
        try {
            DaemonSessions.call(daemonName, sharedConsumerId, id, method, params || ({}));
            return true;
        } catch (error) {
            setPending(id, false);
            const message = "Could not send " + daemonName + " request " + id + ": " + error;
            console.error("shelllist " + daemonName + " request failed id=" + id + " stage=send error=" + error);
            sendFailed(id, message);
            return false;
        }
    }

    function cancel(requestId: string, cancellationId: string): bool {
        if (!requestId)
            return false;
        try {
            DaemonSessions.cancel(daemonName, sharedConsumerId, requestId,
                cancellationId || ("cancel-" + requestId));
            return true;
        } catch (error) {
            const message = "Could not cancel " + daemonName + " request " + requestId + ": " + error;
            console.error("shelllist " + daemonName + " cancellation failed request_id=" + requestId + " error=" + error);
            sendFailed(cancellationId || requestId, message);
            return false;
        }
    }

    function isTransportControl(id: string): bool {
        return id === "session-subscribe" || id.startsWith("cancel-") || id.startsWith("shutdown-")
            || id.startsWith("subscribe-");
    }

    /// Subscribes to extra streams for as long as a view needs them. Returns
    /// the request id; the resulting subscription id arrives asynchronously and
    /// is what `unsubscribe` cancels.
    function subscribeStreams(streamNames: var): string {
        const id = "subscribe-" + (++subscriptionSequence);
        setPending(id, true);
        try {
            DaemonSessions.subscribe(daemonName, sharedConsumerId, id, streamNames, false);
            return id;
        } catch (error) {
            setPending(id, false);
            console.error("shelllist " + daemonName + " subscribe failed id=" + id + " error=" + error);
            return "";
        }
    }

    function unsubscribeStreams(id: string): bool {
        if (!id)
            return false;
        const subscriptionId = extraSubscriptions[id] || "";
        const next = Object.assign({}, extraSubscriptions);
        delete next[id];
        extraSubscriptions = next;
        if (subscriptionId.length > 0)
            return cancel(subscriptionId);
        if (!isPending(id))
            return false;
        const cancellations = Object.assign({}, extraSubscriptionCancellations);
        cancellations[id] = true;
        extraSubscriptionCancellations = cancellations;
        return true;
    }

    function extraSubscriptionId(envelope: var): string {
        const subscription = envelope && envelope.data ? (envelope.data.subscription || ({})) : ({});
        return subscription.id || "";
    }

    function rememberExtraSubscription(id: string, envelope: var): void {
        const subscriptionId = extraSubscriptionId(envelope);
        if (!subscriptionId)
            return;
        const next = Object.assign({}, extraSubscriptions);
        next[id] = subscriptionId;
        extraSubscriptions = next;
    }

    function finishExtraSubscription(id: string, envelope: var, transportError: string): void {
        const cancelWhenReady = !!extraSubscriptionCancellations[id];
        if (cancelWhenReady) {
            const cancellations = Object.assign({}, extraSubscriptionCancellations);
            delete cancellations[id];
            extraSubscriptionCancellations = cancellations;
        }
        if (transportError.length > 0) {
            console.warn("shelllist " + daemonName + " subscribe failed id=" + id + " error=" + transportError);
            return;
        }
        const subscriptionId = extraSubscriptionId(envelope);
        if (cancelWhenReady) {
            if (subscriptionId.length > 0)
                cancel(subscriptionId);
            return;
        }
        rememberExtraSubscription(id, envelope);
    }

    function acceptResponse(id: string, envelope: var, transportError: string): void {
        setPending(id, false);
        if (id.startsWith("subscribe-")) {
            finishExtraSubscription(id, envelope, transportError);
            return;
        }
        if (!isTransportControl(id))
            responseReceived(id, envelope, transportError);
    }

    function failTransport(message: string): void {
        const lostRequestIds = Object.keys(pending);
        pending = ({});
        // A new session resubscribes from scratch, so stale ids must not be
        // cancelled later against a subscription that no longer exists.
        extraSubscriptions = ({});
        extraSubscriptionCancellations = ({});
        transportFailed(message, lostRequestIds);
    }

    function eventEnvelopeError(event: var): string {
        const compatibility = Core.ApiEnvelope.compatibilityError(event,
            expectedProtocol, expectedVersion, daemonName);
        if (compatibility.length > 0)
            return compatibility;
        if (typeof event.stream !== "string" || event.stream.length === 0
                || typeof event.event !== "string" || event.event.length === 0)
            return daemonName + " returned a malformed event";
        return "";
    }

    function isEventGap(event: var): bool {
        return event.event === "lagged"
            || !!(event.data && event.data.resync_required);
    }

    function acceptEvent(event: var): void {
        const error = eventEnvelopeError(event);
        if (error.length > 0) {
            console.warn("shelllist " + daemonName
                + " event rejected error=" + error);
            return;
        }
        if (isEventGap(event)) {
            eventGapDetected(event.stream, event);
            return;
        }
        eventReceived(event);
    }

    function acceptSharedResponse(id: string, envelope: var, transportError: string): void {
        acceptResponse(id, envelope, transportError);
    }

    function acceptSharedEvent(event: var): void {
        acceptEvent(event);
    }

    function failSharedTransport(message: string): void {
        failTransport(message);
    }

    function updateSharedSession(): void {
        if (!sharedConsumerId)
            return;
        DaemonSessions.update(daemonName, sharedConsumerId, active, streams,
            recoverProtocolErrors);
    }

    Component.onCompleted: {
        sharedConsumerId = DaemonSessions.attach(backend);
        if (ready)
            transportReady();
    }
    Component.onDestruction: {
        if (sharedConsumerId)
            DaemonSessions.detach(daemonName, sharedConsumerId);
    }
    onActiveChanged: updateSharedSession()
    onStreamsChanged: updateSharedSession()
    onRecoverProtocolErrorsChanged: updateSharedSession()
    onReadyChanged: if (ready) transportReady()
}
