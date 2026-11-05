.pragma library

// Resource reservations survive their views. No payloads, streams, drafts or
// effect authority live here. Unknown entries are never evicted by age/pressure.
var maximumResources = 256;
var maximumLocalId = 512;
var maximumNativeId = 1024;

function reserve(session, key, consumerId, localId, kind) {
    if (Object.keys(session.resources).length >= maximumResources
            || localId.length > maximumLocalId || consumerId.length > 64)
        throw new Error("UNSENT: subscription cleanup reservation capacity exceeded");
    const record = {key: key, consumerId: consumerId, localId: localId,
        generation: session.generation, owner: session.owner, kind: kind, wanted: true,
        state: kind === "release" ? "dormant" : "pending", nativeId: "", controlId: "",
        protocol: "", version: 0};
    session.resources[key] = record;
    return record;
}

function definiteUnsent(error) {
    const message = typeof error === "string" ? error : error?.message;
    return typeof message === "string" && message.startsWith("UNSENT:");
}

function matches(record, route) {
    return record && record.consumerId === route.consumerId && record.localId === route.localId
        && record.kind === route.kind && record.generation === route.generation;
}

function find(session, consumerId, localId) {
    return Object.values(session.resources).find(record => record.kind !== "release"
        && record.consumerId === consumerId && record.localId === localId && record.wanted);
}

function retireView(record) {
    record.wanted = false;
    if (record.state === "live" || record.state === "dormant")
        record.state = "cleanup";
}

function next(session) {
    const records = Object.values(session.resources);
    if (records.some(record => record.state === "sending"))
        return null; // one reserved cleanup lane, including queued attempts
    return records.find(record => record.state === "cleanup" && (record.kind !== "release"
        || !records.some(other => other !== record && other.consumerId === record.consumerId
            && other.generation === record.generation && other.state !== "uncertain"))) || null;
}

function object(value) {
    return !!value && typeof value === "object" && !Array.isArray(value);
}

// Common native control envelope, not a domain result-schema registration.
function domainSuccess(record, envelope) {
    return record.protocol.length > 0 && Number.isSafeInteger(record.version) && record.version > 0
        && object(envelope) && envelope.protocol === record.protocol && envelope.version === record.version
        && envelope.ok === true && !("error" in envelope) && object(envelope.data);
}

function subscriptionReceipt(record, envelope, error) {
    if (error || !domainSuccess(record, envelope) || !object(envelope.data.subscription))
        return false;
    const id = envelope.data.subscription.id;
    return typeof id === "string" && id.length > 0 && id.length <= maximumNativeId;
}

// Receipt admission changes resource responsibility only. The session owns
// view delivery, base-subscription publication and progress scheduling.
function acceptSubscription(session, record, route, envelope, error) {
    if (!matches(record, route) || record.owner !== session.owner
            || !["pending", "uncertain"].includes(record.state))
        return false;
    const late = record.state === "uncertain";
    const valid = subscriptionReceipt(record, envelope, error);
    if (late && (!valid || record.nativeId))
        return false;
    if (!valid) {
        record.state = "uncertain";
        return true;
    }
    if (late) record.wanted = false;
    record.nativeId = envelope.data.subscription.id;
    record.state = "live";
    return true;
}

function complete(session, record, envelope, error) {
    // Absence/failure is not successful disposition. Retry ONLY requestUnsent,
    // whose exact serialized cancellation has definitely never been written.
    const acknowledged = !error && (record.kind === "release"
        ? object(envelope) && Object.keys(envelope).length === 1 && Number.isSafeInteger(envelope.released) && envelope.released >= 0
        : domainSuccess(record, envelope) && envelope.data.kind === "subscription" && envelope.data.cancelled === record.nativeId);
    if (acknowledged)
        delete session.resources[record.key];
    else
        record.state = "uncertain";
}
