.pragma library

function isFailureKind(kind) {
    return kind === "transport-error" || kind === "protocol-error";
}

function shouldRecoverFailure(kind, recoverProtocolErrors) {
    return kind === "transport-error" || (kind === "protocol-error" && recoverProtocolErrors);
}

// The bridge and native socket carry the same response payload contract.
// Correlation and resource ownership remain transport-specific.
function responseCorrelationValid(message) {
    return typeof message.id === "string" && message.id.length > 0 && typeof message.ok === "boolean";
}

function responsePayloadValid(message) {
    if (message.ok)
        return !!message.response && typeof message.response === "object" && !Array.isArray(message.response);
    return typeof message.error === "string" && ["rejected-before-dispatch", "outcome-unknown"].includes(message.outcome);
}

function responseOutcome(message, daemonName) {
    const subscriptionFailure = !message.route && message.id === "session-subscribe" && !message.ok;
    const fallback = subscriptionFailure ? daemonName + " subscription failed" : daemonName + " call failed";
    return {
        id: message.id || "",
        envelope: message.ok ? message.response : null,
        error: message.ok ? "" : (message.error || fallback),
        recover: subscriptionFailure,
        route: message.route || null
    };
}

// The session subscription is the one whose failure means the transport is
// unusable. Extra, on-demand subscriptions are identified separately so a
// failure there is reported without tearing the session down.
function isExtraSubscribe(id) {
    return typeof id === "string" && id.indexOf("subscribe-") === 0;
}

function subscriptionId(message) {
    if (!message.ok || !message.response || !message.response.data)
        return "";
    if (message.id !== "session-subscribe" && !isExtraSubscribe(message.id))
        return "";
    return ((message.response.data.subscription || ({})).id || "");
}
