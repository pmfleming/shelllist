pragma ComponentBehavior: Bound
import QtQuick
import "../Bar/BarProtocol.generated.js" as Protocol

// Native per-domain publication cursors, not writer/event counters. Recovery
// reads replace current state; they never reconstruct lost edges or replay work.
QtObject {
    id: recovery
    required property BarDaemonBackend backend
    property int generation: 0
    property var requests: ({})
    property var methods: ({})
    property var epochs: ({}) // conservative gap barriers, not native revisions
    property var cursors: ({})
    property var dirty: ({})
    property var paused: ({})
    property var values: ({})
    property string error: ""
    property int snapshotRequests: 0
    property int gaps: 0
    property int discardedReplies: 0
    property int snapshotFailures: 0
    property Component cursorFactory: Component { SnapshotCursor {} }
    readonly property var ordered: ["battery.changed", "power-sleep.changed", "notifications.active.changed", "osd-hardware.changed"]
    readonly property var keys: ({
        "theme.changed": "theme", "activity.changed": "activity", "workspaces.changed": "workspaces",
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
        methods[id] = method;
        if (method !== "bar.snapshot")
            return params;
        const domains = params.streams || Array.from(backend.streams);
        domains.forEach(stream => delete paused[stream]);
        requests = Object.assign({}, requests, {[id]: {generation: generation, streams: domains, epochs: Object.assign({}, epochs)}});
        snapshotRequests++;
        return Object.assign({}, params, {streams: domains});
    }
    function sendFailed(id: string): void {
        const context = requests[id];
        if (context) context.streams.forEach(stream => paused[stream] = true);
        forget(id);
    }
    function forget(id: string): void {
        delete methods[id];
        const next = Object.assign({}, requests);
        delete next[id];
        requests = next;
    }
    function reject(stream: string, message: string): void {
        error = message;
        const wasPaused = paused[stream];
        paused[stream] = true;
        snapshotFailures++;
        if (!wasPaused && Array.from(backend.streams).includes(stream))
            backend.eventReceived({stream: stream, event: "subscribed", data: Object.assign({}, values[stream] || {}, {available: false, error: message})});
    }
    function cursor(stream: string): var {
        if (!cursors[stream]) cursors[stream] = cursorFactory.createObject(recovery);
        return cursors[stream];
    }
    function payload(value: var): var {
        const result = Object.assign({}, value);
        delete result._publication;
        return result;
    }
    function validate(stream: string, value: var): bool {
        const failure = Protocol.eventError({protocol: Protocol.protocol, version: Protocol.version,
            stream: stream, event: "subscribed", data: value});
        if (failure) {
            reject(stream, "Invalid native bar projection; matching daemon required: " + failure);
            return false;
        }
        return true;
    }
    function accept(stream: string, value: var, read: bool): var {
        if (!validate(stream, value)) return undefined;
        const c = cursor(stream);
        const accepted = c.accept(value._publication, function() { values[stream] = payload(value); });
        if (accepted) {
            error = "";
            delete dirty[stream];
            delete paused[stream];
            return values[stream];
        }
        if (c.error) reject(stream, c.error);
        else if (read && c.epoch === value._publication.epoch && value._publication.revision <= c.revision) {
            // Reopening a view may need the already accepted value. Never publish
            // the stale/duplicate read's body, even when its revision is equal.
            delete dirty[stream];
            delete paused[stream];
            error = "";
            return values[stream];
        } else if (read) reject(stream, "Unrelated bar publication epoch; reconnect required");
        discardedReplies++;
        return undefined;
    }
    function invalidEvent(event: var, message: string): void {
        if (event && keys[event.stream] && ["changed", "subscribed"].includes(event.event))
            reject(event.stream, message + "; matching daemon required");
    }
    function observe(event: var): var {
        const stream = event.stream;
        if (!keys[stream]) return event;
        if (backend.isEventGap(event)) {
            epochs[stream] = (epochs[stream] || 0) + 1;
            gaps++;
            dirty[stream] = true;
            return event;
        }
        if (!["subscribed", "changed"].includes(event.event)) return false;
        const c = cursor(stream);
        const stamp = event.data?._publication;
        const discontinuous = !!dirty[stream] || (ordered.includes(stream) && c.epoch
            && (stamp?.epoch !== c.epoch || stamp?.revision > c.revision + 1));
        const value = accept(stream, event.data, false);
        if (value === undefined) return false;
        // A full projection repairs state but cannot recreate missed OSD/sleep/
        // notification transitions. Consumers receive a baseline, not an edge.
        return Object.assign({}, event, {data: value, event: discontinuous ? "subscribed" : event.event});
    }
    function recover(stream: string): void {
        if (!keys[stream] || !Array.from(backend.streams).includes(stream)) return;
        dirty[stream] = true;
        delete paused[stream];
        drain();
    }
    function drain(): void {
        Object.keys(dirty).forEach(function(stream) {
            if (!paused[stream] && !busy([stream]) && backend.active)
                backend.snapshotRequest(backend.nextRequestId("state-resync"), [stream]);
        });
    }
    function received(id: string, envelope: var, transportError: string): var {
        const context = requests[id];
        const method = methods[id];
        forget(id);
        if (context && context.generation !== generation) return undefined;
        const internal = id.startsWith("state-resync-");
        const failure = backend.responseError(envelope, transportError, "Bar state recovery failed");
        if (failure) {
            if (context) context.streams.forEach(stream => reject(stream, failure));
            return internal ? undefined : envelope;
        }
        const data = Object.assign({}, envelope.data);
        // Pure previews are request-scoped calculations, not shared live state.
        if (method === "theme.resolve") return envelope;
        const observations = Object.assign({}, data.observations || {});
        const snapshot = data.snapshot || {};
        const accepted = {};
        const domains = context ? context.streams : Object.keys(keys).filter(stream => snapshot[keys[stream]] !== undefined || data[keys[stream]] !== undefined);
        domains.forEach(function(stream) {
            const key = keys[stream];
            if (!key) return;
            if (data[key] !== undefined) {
                observations[key] = data[key];
                delete data[key];
            }
            if (context && (context.epochs[stream] || 0) !== (epochs[stream] || 0)) {
                discardedReplies++;
                return;
            }
            if (snapshot[key] !== undefined) {
                const value = accept(stream, snapshot[key], true);
                if (value !== undefined) {
                    accepted[key] = value;
                    if (internal) backend.eventReceived({stream: stream, event: "subscribed", data: value});
                }
            } else if (context) {
                reject(stream, "Missing native bar projection; matching daemon required: " + stream);
            } else if (Array.from(backend.streams).includes(stream)) {
                // Legacy effect replies remain acknowledgements only. Recovery
                // still requires a matching stamped producer, on either transport.
                dirty[stream] = true;
                delete paused[stream];
            }
        });
        data.snapshot = accepted;
        data.observations = observations;
        Qt.callLater(drain);
        return internal ? undefined : Object.assign({}, envelope, {data: data});
    }
    function reset(message: string): void {
        generation++;
        requests = ({});
        methods = ({});
        epochs = ({});
        Object.values(cursors).forEach(c => c.destroy());
        cursors = ({});
        dirty = ({});
        paused = ({});
        Array.from(backend.streams).forEach(function(stream) {
            const value = Object.assign({}, values[stream] || {}, {available: false, error: message});
            values[stream] = value;
            backend.eventReceived({stream: stream, event: "subscribed", data: value});
        });
    }
}
