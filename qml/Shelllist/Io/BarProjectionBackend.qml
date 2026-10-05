import "../Bar/BarProtocol.generated.js" as Protocol

// Read-only snapshot/stream transport. Each consumer owns its projection's
// validation, revision fencing and unavailable-state behavior.
DaemonBackend {
    required property string projection
    required property string failureMessage
    property string snapshotId: projection + "-snapshot"

    signal received(var value)
    signal readFailed

    daemonName: "bar-daemon"
    expectedProtocol: Protocol.protocol
    expectedVersion: Protocol.version
    streams: [Protocol.streams[projection + ".changed"]]

    function refresh(): void {
        if (active)
            call(snapshotId, Protocol.methods["bar.snapshot"], {});
    }
    onTransportReady: refresh()
    onEventGapDetected: refresh()
    onResponseReceived: function (id, envelope, transportError) {
        if (responseError(envelope, transportError, failureMessage))
            readFailed();
        else
            received(envelope.data && envelope.data.snapshot ? envelope.data.snapshot[projection] : null);
    }
    onEventReceived: function (event) {
        if (event.stream === streams[0])
            received(event.data);
    }
}
