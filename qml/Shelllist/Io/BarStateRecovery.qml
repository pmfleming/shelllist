import QtQuick

// One in-flight read per domain/consumer, including startup/manual snapshots.
// Local event epochs fence v1 replies without changing the v1 event envelope.
QtObject {
    required property var backend
    property int generation: 0
    property var requests: ({})
    property var responseEpochs: ({})
    property var epochs: ({})
    property var dirty: ({})
    property var paused: ({})
    property var values: ({})
    property int snapshotRequests: 0
    property int gaps: 0
    property int discardedReplies: 0
    property int snapshotFailures: 0

    readonly property var keys: ({
        "activity.changed": "activity", "workspaces.changed": "workspaces",
        "workarea.changed": "workarea", "compositor.changed": "compositor",
        "media.changed": "media", "audio.changed": "audio", "brightness.changed": "brightness",
        "battery.changed": "battery", "power-profile.changed": "power_profile",
        "power-sleep.changed": "power_sleep", "sleep-policy.changed": "sleep_policy",
        "display-policy.changed": "display_policy", "osd-hardware.changed": "osd_hardware",
        "notifications.changed": "notifications", "notifications.active.changed": "notification_active",
        "updates.changed": "updates", "timezone.changed": "timezone"
    })

    function busy(streams: var): bool {
        return Object.keys(requests).some(id => requests[id].streams.some(stream => streams.includes(stream)));
    }
    function sending(id: string, method: string, params: var): var {
        if (method !== "bar.snapshot") {
            responseEpochs[id] = Object.assign({}, epochs);
            return params;
        }
        const domains = params.streams || Array.from(backend.streams);
        domains.forEach(stream => delete paused[stream]);
        const next = Object.assign({}, requests);
        next[id] = {generation: generation, streams: domains, epochs: Object.assign({}, epochs), started: Date.now()};
        requests = next;
        snapshotRequests += 1;
        return Object.assign({}, params, {streams: domains});
    }
    function sendFailed(id: string): void {
        const context = requests[id];
        if (context)
            context.streams.forEach(stream => paused[stream] = true);
        forget(id);
    }
    function forget(id: string): void {
        delete responseEpochs[id];
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
    }
    function observe(event: var): void {
        const stream = event.stream;
        if (!keys[stream] || (!backend.isEventGap(event) && !["subscribed", "changed"].includes(event.event)))
            return;
        epochs[stream] = (epochs[stream] || 0) + 1;
        if (backend.isEventGap(event)) {
            gaps += 1;
            dirty[stream] = true;
        } else if (["subscribed", "changed"].includes(event.event)) {
            // Every bar state event is a complete domain projection.
            values[stream] = event.data;
            delete dirty[stream];
            delete paused[stream];
        }
    }
    function recover(stream: string): void {
        if (!keys[stream] || !Array.from(backend.streams).includes(stream))
            return;
        dirty[stream] = true;
        delete paused[stream];
        drain();
    }
    function drain(): void {
        Object.keys(dirty).forEach(function (stream) {
            if (!paused[stream] && !busy([stream]) && backend.active)
                backend.snapshotRequest(backend.nextRequestId("state-resync"), [stream]);
        });
    }
    function received(id: string, envelope: var, transportError: string): var {
        const context = requests[id];
        if (!context) {
            const sent = responseEpochs[id];
            delete responseEpochs[id];
            if (envelope && envelope.ok && envelope.data && !backend.responseError(envelope, transportError, "Bar operation failed")) {
                const data = Object.assign({}, envelope.data);
                Object.keys(keys).forEach(function (stream) {
                    const key = keys[stream];
                    const value = data[key];
                    if (value === undefined)
                        return;
                    if (sent && (sent[stream] || 0) !== (epochs[stream] || 0)) {
                        delete data[key];
                        discardedReplies += 1;
                    } else {
                        values[stream] = value;
                        epochs[stream] = (epochs[stream] || 0) + 1;
                    }
                });
                envelope = Object.assign({}, envelope, {data: data});
            }
            return id.startsWith("state-resync-") ? undefined : envelope;
        }
        forget(id);
        if (context.generation !== generation)
            return undefined;
        const recovery = id.startsWith("state-resync-");
        const error = backend.responseError(envelope, transportError, "Bar state recovery failed");
        if (error) {
            context.streams.forEach(stream => paused[stream] = true);
            snapshotFailures += 1;
            console.warn("shelllist bar state read failed domains=" + context.streams.join(",") + " error=" + error);
            // Do not spin on a failing daemon. The next gap, explicit refresh,
            // or transport generation retries this read, never an effect.
            return recovery ? undefined : envelope;
        }
        const snapshot = (envelope.data || {}).snapshot || {};
        const accepted = {};
        context.streams.forEach(function (stream) {
            const key = keys[stream];
            if ((context.epochs[stream] || 0) !== (epochs[stream] || 0)) {
                discardedReplies += 1;
                return;
            }
            if (snapshot[key] === undefined) {
                if (dirty[stream]) {
                    paused[stream] = true;
                    snapshotFailures += 1;
                    console.warn("shelllist bar recovery missing domain=" + stream);
                }
                return;
            }
            accepted[key] = snapshot[key];
            values[stream] = snapshot[key];
            delete dirty[stream];
            if (recovery)
                backend.eventReceived({stream: stream, event: "subscribed", data: snapshot[key]});
        });
        console.debug("shelllist bar snapshot latency_ms=" + (Date.now() - context.started) + " domains=" + context.streams.length);
        Qt.callLater(drain);
        if (recovery)
            return undefined;
        // Older daemons ignore streams and return a full snapshot. Project it
        // here too, and never let an old read replace a newer event's domain.
        return Object.assign({}, envelope, {data: Object.assign({}, envelope.data, {snapshot: accepted})});
    }
    function reset(message: string): void {
        generation += 1;
        requests = ({});
        responseEpochs = ({});
        epochs = ({});
        dirty = ({});
        paused = ({});
        Array.from(backend.streams).forEach(function (stream) {
            const value = Object.assign({}, values[stream] || {}, {available: false, error: message});
            values[stream] = value;
            backend.eventReceived({stream: stream, event: "subscribed", data: value});
        });
    }
}
