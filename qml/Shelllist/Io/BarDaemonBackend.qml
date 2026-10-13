import QtQuick

DaemonBackend {
    id: barBackend
    requestPolicy: BarStateRecovery { backend: barBackend }

    function snapshotPending(): bool {
        return requestPolicy.busy(Array.from(streams));
    }
    function snapshotRequest(id: string, domains: var): bool {
        const selected = domains || Array.from(streams);
        if (requestPolicy.busy(selected))
            return false;
        return call(id, "bar.snapshot", {streams: selected});
    }
    onEventGapDetected: function (stream) { requestPolicy.recover(stream); }
}
