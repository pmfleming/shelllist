import QtQuick
import Shelllist.Core as Core

Item {
    id: backend

    required property string daemonName
    property string expectedProtocol: ""
    property int expectedVersion: 0
    property list<string> streams: []
    required property bool active
    property bool recoverProtocolErrors: true
    property var pending: ({})
    property int requestSequence: 0
    property int subscriptionSequence: 0
    property string sharedConsumerId: ""
    // Optional domain policy; transport routing/ownership remains here.
    property var requestPolicy: null
    property var validateRequest: null
    property var validateEvent: null
    // Local, non-secret classification captured before dispatch. Never sent as
    // daemon authorization, and never inferred from a caller-chosen request ID.
    function classifyRequest(method: string, params: var): var {
        return ({});
    }
    property var requestMetadata: ({})
    // Identity-scoped completion window. Policy callbacks such as readDiscarded
    // may deliberately submit a replacement, after received() captured/forgot its
    // original context but before the public pending notification is emitted.
    property var completingRequests: ({})

    readonly property bool requestRunning: pendingCount > 0
    readonly property int pendingCount: Object.keys(pending).length
    readonly property bool ready: {
        DaemonSessions.revision;
        // A resident session may already be ready during construction. Do
        // not dispatch startup requests until this backend has its route ID.
        return sharedConsumerId.length > 0 && DaemonSessions.isReady(daemonName);
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

    function renewBaseSubscription(): bool {
        return DaemonSessions.renewBaseSubscription(daemonName, sharedConsumerId);
    }

    function isPending(id: string): bool {
        const completion = completingRequests[id];
        return !!pending[id] && !(completion && completion.window === pending[id]);
    }

    /// The `prefix` a `callSequenced` id was built from.
    function requestKind(id: string): string {
        return id.replace(/-\d+$/, "");
    }

    function nextRequestId(prefix: string): string {
        requestSequence += 1;
        return prefix + "-" + requestSequence;
    }

    function callSequenced(prefix: string, method: string, params: var): bool {
        return call(nextRequestId(prefix), method, params || ({}));
    }

    function responseError(envelope: var, transportError: string, fallbackMessage: string): string {
        return Core.ApiEnvelope.responseError(envelope, transportError, expectedProtocol, expectedVersion, daemonName, fallbackMessage);
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
            next[id] = {}; // unique pending window, independent of consumer-owned metadata
        else
            delete next[id];
        pending = next;
    }

    function forgetRequestMetadata(id: string, expected: var): void {
        if (requestMetadata[id] !== expected)
            return; // A completion callback may already have reused this ID.
        const next = Object.assign({}, requestMetadata);
        delete next[id];
        requestMetadata = next;
    }

    function recordRequestMetadata(id: string, metadata: var): void {
        requestMetadata = Object.assign({}, requestMetadata, {[id]: metadata});
    }

    function call(id: string, method: string, params: var): bool {
        if (isPending(id)) {
            console.warn("shelllist " + daemonName + " request rejected id=" + id + " reason=already-pending");
            return false;
        }
        const metadata = Object.assign({}, classifyRequest(method, params || ({})), {kind: "call", method: method});
        recordRequestMetadata(id, metadata);
        const validationError = validateRequest ? validateRequest(method, params || ({})) : "";
        if (validationError) {
            sendFailed(id, "Request rejected before dispatch: " + validationError);
            forgetRequestMetadata(id, metadata);
            return false;
        }
        if (requestPolicy)
            params = requestPolicy.sending(id, method, params || ({}));
        setPending(id, true);
        const window = pending[id];
        try {
            DaemonSessions.call(daemonName, sharedConsumerId, id, method, params || ({}));
            return true;
        } catch (error) {
            const message = "Could not send " + daemonName + " request " + id + ": " + error;
            console.error("shelllist " + daemonName + " request failed id=" + id + " stage=send error=" + error);
            finishUnsent(id, metadata, window, message);
            return false;
        }
    }

    // Missing typed string arguments become "undefined" in QML. Keep the
    // default-ID entry point separate from callers supplying an explicit ID.
    function cancel(requestId: string): bool {
        return cancelWithId(requestId, "cancel-" + requestId);
    }

    function cancelWithId(requestId: string, cancellationId: string): bool {
        if (!requestId)
            return false;
        try {
            DaemonSessions.cancel(daemonName, sharedConsumerId, requestId, cancellationId || ("cancel-" + requestId));
            return true;
        } catch (error) {
            const message = "Could not cancel " + daemonName + " request " + requestId + ": " + error;
            console.error("shelllist " + daemonName + " cancellation failed request_id=" + requestId + " error=" + error);
            sendFailed(cancellationId || requestId, message);
            return false;
        }
    }

    function isTransportControl(id: string): bool {
        const metadata = requestMetadata[id];
        if (metadata)
            return metadata.kind !== "call";
        return id === "session-subscribe" || id.startsWith("cancel-") || id.startsWith("shutdown-") || id.startsWith("subscribe-");
    }

    /// Subscribes to extra streams for as long as a view needs them. Returns
    /// the request id; the resulting subscription id arrives asynchronously and
    /// is what `unsubscribe` cancels.
    function subscribeStreams(streamNames: var): string {
        if (subscriptionSequence >= 2147483647)
            return ""; // exhausted local windows must never alias a live resource
        const id = "subscribe-" + (++subscriptionSequence);
        const metadata = {kind: "subscription"};
        recordRequestMetadata(id, metadata);
        setPending(id, true);
        try {
            DaemonSessions.subscribe(daemonName, sharedConsumerId, id, streamNames, false);
            return id;
        } catch (error) {
            setPending(id, false);
            console.error("shelllist " + daemonName + " subscribe failed id=" + id + " error=" + error);
            forgetRequestMetadata(id, metadata);
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
            return DaemonSessions.unsubscribe(daemonName, sharedConsumerId, id);
        if (!isPending(id))
            return false;
        const cancellations = Object.assign({}, extraSubscriptionCancellations);
        cancellations[id] = true;
        extraSubscriptionCancellations = cancellations;
        return DaemonSessions.unsubscribe(daemonName, sharedConsumerId, id);
    }

    function extraSubscriptionId(envelope: var): string {
        const subscription = envelope && envelope.data ? (envelope.data.subscription || ({})) : ({});
        return subscription.id || "";
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
        if (cancelWhenReady)
            return; // session reservation owns cleanup, even after this view disappears
        if (subscriptionId.length > 0 && DaemonSessions.ownsSubscription(daemonName, sharedConsumerId, id, subscriptionId)) {
            const next = Object.assign({}, extraSubscriptions);
            next[id] = subscriptionId;
            extraSubscriptions = next;
        }
    }

    function withCompletionContext(id: string, metadata: var, window: var, deliver: var): void {
        const replacement = requestMetadata[id];
        const replacementWindow = pending[id];
        const completion = replacementWindow === window ? {window: window} : null;
        if (completion)
            completingRequests[id] = completion;
        if (replacement !== metadata)
            recordRequestMetadata(id, metadata); // completion-time readers need the captured target
        try {
            deliver();
        } finally {
            if (completion && completingRequests[id] === completion)
                delete completingRequests[id];
            // A domain callback may consume the completing metadata itself.
            // Restore the saved live context only while its exact window owns ID.
            if (replacement !== metadata && pending[id] === replacementWindow
                    && (requestMetadata[id] === metadata || requestMetadata[id] === undefined)) {
                if (replacement === undefined)
                    forgetRequestMetadata(id, metadata);
                else
                    recordRequestMetadata(id, replacement);
            }
        }
    }

    function acceptSharedResponse(id: string, envelope: var, transportError: string): void {
        const metadata = requestMetadata[id];
        const window = pending[id];
        const transportControl = isTransportControl(id);
        const policy = requestPolicy;
        try {
            if (!transportControl) {
                if (policy) {
                    // Consume the old policy transaction BEFORE pendingChanged
                    // can replace requests[id]. Policy-originated replacement
                    // callbacks remain allowed in this identity-scoped window.
                    const completion = {window: window};
                    completingRequests[id] = completion;
                    try {
                        envelope = policy.received(id, envelope, transportError);
                    } finally {
                        if (completingRequests[id] === completion)
                            delete completingRequests[id];
                    }
                }
            }
            if (metadata ? metadata.kind === "subscription" : id.startsWith("subscribe-")) {
                if (pending[id] === window)
                    setPending(id, false);
                finishExtraSubscription(id, envelope, transportError);
                return;
            }
            // Deliver while the original metadata is still visible. Emitting
            // pendingChanged first would let it replace the downstream target.
            // Deliberate response-handler ID reuse remains allowed by isPending.
            if (!transportControl && envelope !== undefined)
                withCompletionContext(id, metadata, window, () => responseReceived(id, envelope, transportError));
        } finally {
            if (window && pending[id] === window)
                setPending(id, false);
            forgetRequestMetadata(id, metadata);
        }
    }

    function acceptSharedUnsent(id: string, message: string): void {
        finishUnsent(id, requestMetadata[id], pending[id], message);
    }

    function finishUnsent(id: string, metadata: var, window: var, message: string): void {
        try {
            // Retire the original policy transaction before public notification.
            // This is definitely unsent, never a dispatched uncertainty response.
            if (metadata?.kind === "call" && requestPolicy)
                requestPolicy.sendFailed(id);
            if (metadata?.kind === "subscription")
                finishExtraSubscription(id, null, message);
            withCompletionContext(id, metadata, window, () => sendFailed(id, message));
        } finally {
            if (window && pending[id] === window)
                setPending(id, false);
            forgetRequestMetadata(id, metadata);
        }
    }

    function failSharedTransport(message: string): void {
        const lostRequestIds = Object.keys(pending);
        const lostMetadata = requestMetadata;
        pending = ({});
        // A new session resubscribes from scratch, so stale ids must not be
        // cancelled later against a subscription that no longer exists.
        extraSubscriptions = ({});
        extraSubscriptionCancellations = ({});
        if (requestPolicy)
            requestPolicy.reset(message);
        transportFailed(message, lostRequestIds);
        Object.keys(lostMetadata).forEach(id => forgetRequestMetadata(id, lostMetadata[id]));
    }

    function eventEnvelopeError(event: var): string {
        const compatibility = Core.ApiEnvelope.compatibilityError(event, expectedProtocol, expectedVersion, daemonName);
        if (compatibility.length > 0)
            return compatibility;
        if (typeof event.stream !== "string" || event.stream.length === 0 || typeof event.event !== "string" || event.event.length === 0 || !event.data || typeof event.data !== "object" || Array.isArray(event.data))
            return daemonName + " returned a malformed event";
        return validateEvent ? validateEvent(event) : "";
    }

    function isEventGap(event: var): bool {
        return event.event === "gap";
    }

    function acceptSharedEvent(event: var): void {
        const error = eventEnvelopeError(event);
        if (error.length > 0) {
            console.warn("shelllist " + daemonName + " event rejected error=" + error);
            if (requestPolicy && typeof requestPolicy.invalidEvent === "function")
                requestPolicy.invalidEvent(event, error);
            return;
        }
        if (requestPolicy) {
            const observed = requestPolicy.observe(event);
            if (observed === false)
                return;
            if (observed && typeof observed === "object")
                event = observed;
        }
        if (isEventGap(event)) {
            eventGapDetected(event.stream, event);
            return;
        }
        eventReceived(event);
    }

    function updateSharedSession(): void {
        if (!sharedConsumerId)
            return;
        DaemonSessions.update(daemonName, sharedConsumerId, active, streams, recoverProtocolErrors);
    }

    Component.onCompleted: {
        sharedConsumerId = DaemonSessions.attach(backend);
    }
    Component.onDestruction: {
        if (sharedConsumerId)
            DaemonSessions.detach(daemonName, sharedConsumerId);
    }
    onActiveChanged: updateSharedSession()
    onStreamsChanged: updateSharedSession()
    onRecoverProtocolErrorsChanged: updateSharedSession()
    onReadyChanged: if (ready)
        transportReady()
}
