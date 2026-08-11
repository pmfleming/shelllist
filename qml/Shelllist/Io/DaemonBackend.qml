import QtQuick
import "process"

Item {
    id: backend

    required property string daemonName
    required property var streams
    property bool active
    property bool recoverProtocolErrors: true
    property var pending: ({})

    readonly property bool requestRunning: pendingCount > 0
    readonly property int pendingCount: Object.keys(pending).length
    readonly property alias ready: client.ready

    signal responseReceived(string id, var envelope, string transportError)
    signal eventReceived(var event)
    signal transportFailed(string message, var lostRequestIds)
    signal transportReady
    signal sendFailed(string id, string message)

    function isPending(id: string): bool { return !!pending[id]; }

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
            client.call(id, method, params || ({}));
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
            if (cancellationId)
                client.cancel(cancellationId, requestId);
            else
                client.cancel(requestId);
            return true;
        } catch (error) {
            const message = "Could not cancel " + daemonName + " request " + requestId + ": " + error;
            console.error("shelllist " + daemonName + " cancellation failed request_id=" + requestId + " error=" + error);
            sendFailed(cancellationId || requestId, message);
            return false;
        }
    }

    function isTransportControl(id: string): bool {
        return id === "session-subscribe" || id.startsWith("cancel-") || id.startsWith("shutdown-");
    }

    function acceptResponse(id: string, envelope: var, transportError: string): void {
        setPending(id, false);
        if (!isTransportControl(id))
            responseReceived(id, envelope, transportError);
    }

    function failTransport(message: string): void {
        const lostRequestIds = Object.keys(pending);
        pending = ({});
        transportFailed(message, lostRequestIds);
    }

    JsonlDaemonClient {
        id: client
        daemonName: backend.daemonName
        streams: backend.streams
        active: backend.active
        recoverProtocolErrors: backend.recoverProtocolErrors
        onResponse: function (id, envelope, transportError) {
            backend.acceptResponse(id, envelope, transportError);
        }
        onEventReceived: function (event) { backend.eventReceived(event); }
        onTransportFailed: function (message) { backend.failTransport(message); }
        onReadyChanged: if (ready) backend.transportReady()
    }
}
