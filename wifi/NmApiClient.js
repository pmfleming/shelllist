.pragma library
.import "NmApi.js" as NmApi

function pick(source, key) { return key && source ? source[key] : source; }
function isApiEnvelope(response) { return response && response.protocol === NmApi.protocol; }
function apiPayload(response) {
    if (!isApiEnvelope(response))
        throw new Error("Expected nm-api response envelope");
    if (response.version !== NmApi.version)
        throw new Error("Unsupported nm-api protocol version " + response.version);
    return response.data || {};
}
function apiErrorMessage(response) {
    const error = response.error || {};
    return (error.code || "api-error") + ": " + (error.message || "nm-api request failed");
}
function apiErrorResult(response) {
    const error = response.error || {};
    return { status: "error", reason: error.code || "unknown", message: error.message || "nm-api request failed" };
}
function apiData(response, key) {
    const data = apiPayload(response);
    if (!response.ok)
        throw new Error(apiErrorMessage(response));
    return pick(data, key);
}
function apiResult(response, key) {
    const data = apiPayload(response);
    if (!response.ok)
        return key && data[key] ? data[key] : apiErrorResult(response);
    return pick(data, key);
}
function requireApiEvent(event) {
    if (!isApiEnvelope(event) || event.version !== NmApi.version || !event.stream || !event.event)
        throw new Error("Expected nm-api v1 event envelope");
    return event;
}
function scanEventStatus(event, fallback) {
    const messages = {
        snapshot: event.networks_found + (event.scanning ? " networks found; scanning…" : " networks available"),
        complete: event.networks_found + (event.timed_out ? " networks available; scan timed out" : " networks available")
    };
    return messages[event.event] || event.message || fallback;
}
function isTerminalEvent(event) { return event.event === "complete" || event.event === "failed" || event.event === "cancelled"; }
function requestMatches(event, requestId) { return !!event.request_id && event.request_id === requestId; }
function connectEventResult(event) { return event.result || ({ status: "error", reason: event.reason || "unknown", message: event.message || "Connection failed" }); }
function connectEventState(event) { return event.event === "succeeded" ? "succeeded" : (event.event === "failed" || event.event === "cancelled" ? "failed" : "progress"); }
