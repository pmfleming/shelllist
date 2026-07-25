.pragma library

function isFailureKind(kind) {
    return kind === "transport-error" || kind === "protocol-error";
}

function responseOutcome(message, daemonName) {
    const subscriptionFailure = message.id === "session-subscribe" && !message.ok;
    const fallback = subscriptionFailure ? daemonName + " subscription failed" : daemonName + " call failed";
    return {
        id: message.id || "",
        envelope: message.ok ? message.response : null,
        error: message.ok ? "" : (message.error || fallback),
        recover: subscriptionFailure
    };
}

function subscriptionId(message) {
    if (message.id !== "session-subscribe" || !message.ok || !message.response || !message.response.data)
        return "";
    return ((message.response.data.subscription || ({})).id || "");
}
