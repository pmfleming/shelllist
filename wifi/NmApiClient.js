.pragma library
.import "NmApi.js" as NmApi

function pick(source, key) {
    return key && source ? source[key] : source;
}
function isApiEnvelope(response) {
    return response && response.protocol === NmApi.protocol;
}
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
    return {
        status: "error",
        reason: error.code || "unknown",
        message: error.message || "nm-api request failed"
    };
}
function apiData(response, key) {
    const data = apiPayload(response);
    if (!response.ok)
        throw new Error(apiErrorMessage(response));
    return pick(data, key);
}
// Wire shape only. The consumer still owns routing, SnapshotCursor ordering and
// synchronous UI publication; this does not infer missing native status facts.
function statusPayloadError(value) {
    const object = v => v && typeof v === "object" && !Array.isArray(v);
    const invalid = "Invalid native Wi-Fi status; matching nm-daemon required.";
    if (!object(value) || typeof value.available !== "boolean")
        return invalid;
    if (!value.available)
        return "";
    if (typeof value.active !== "boolean" || typeof value.enabled !== "boolean" || !object(value.radios))
        return invalid;
    const radioFlags = ["wireless_enabled", "wireless_hardware_enabled", "wireless_available",
        "wwan_enabled", "wwan_hardware_enabled", "wwan_available", "airplane_mode"];
    if (!radioFlags.every(key => typeof value.radios[key] === "boolean"))
        return invalid;
    const projections = ["access_point", "network", "profile", "connectivity", "ip4", "ip6", "wireless", "metered", "link"];
    if (!projections.every(key => value[key] === null || object(value[key])))
        return invalid;
    return "";
}
function apiResult(response, key) {
    const data = apiPayload(response);
    if (!response.ok)
        return key && data[key] ? data[key] : apiErrorResult(response);
    return pick(data, key);
}
function scanEventStatus(event, fallback) {
    const messages = {
        snapshot: event.data.networks_found + (event.data.scanning ? " networks found; scanning…" : " networks available"),
        complete: event.data.networks_found + (event.data.timed_out ? " networks available; scan timed out" : " networks available")
    };
    return messages[event.event] || event.data.message || fallback;
}
function isTerminalEvent(event) {
    return event.event === "complete" || event.event === "failed" || event.event === "cancelled";
}
function requestMatches(event, requestId) {
    return !!event.request_id && event.request_id === requestId;
}
function connectEventResult(event) {
    return event.data.result || ({
            status: "error",
            reason: event.data.reason || "unknown",
            recovery_prompt: event.data.recovery_prompt || null,
            message: event.data.message || "Connection failed"
        });
}
function connectEventState(event) {
    return event.event === "succeeded" ? "succeeded" : (event.event === "failed" || event.event === "cancelled" ? "failed" : "progress");
}
