import QtQuick
import "NmApi.js" as NmApi

// UI transaction only: policy, identity, URL selection and durable attempts live
// in nm-daemon. Never recover/replay a launch command after transport loss.
Item {
    id: portal
    required property WifiController controller
    required property WifiBackend backend

    property string phase: ""
    property string pendingId: ""
    property string workspaceId: ""
    property var intent: null
    readonly property bool busy: phase.length > 0

    function reset() {
        pendingId = "";
        phase = "";
        intent = null;
        workspaceId = "";
    }
    function fail(message) {
        reset();
        controller.status = message;
    }
    function send(kind, method, params) {
        pendingId = backend.nextRequestId("portal-" + kind);
        phase = kind;
        return backend.call(pendingId, method, params);
    }
    function begin(mode, requestId, workspace, fallback) {
        if (busy || backend.portalExecutor.running) {
            controller.status = "A portal launch is already in progress";
            return false;
        }
        workspaceId = String(workspace || "");
        controller.status = "Preparing captive portal page…";
        const params = {mode: mode, fallback: !!fallback};
        if (mode === "automatic")
            params.connect_request_id = requestId;
        return send("prepare", NmApi.methods.network_portalPrepare, params);
    }
    function launchForConnect(requestId, workspace) {
        return begin("automatic", requestId, workspace, false);
    }
    function launchManual(workspace, fallback) {
        return begin("manual", "", workspace, fallback);
    }
    function validIntent(value) {
        return value && typeof value.launch_id === "string" && value.launch_id.length > 0
            && typeof value.episode === "string" && typeof value.url === "string"
            && typeof value.expires_at_ms === "number" && value.expires_at_ms > Date.now();
    }
    function receive(id, envelope, transportError) {
        if (id !== pendingId)
            return;
        const error = backend.responseError(envelope, transportError, "Portal request failed");
        if (error.length > 0) {
            fail(error + ". Use Sign in to retry manually.");
            return;
        }
        const data = envelope.data ? envelope.data.portal : null;
        const completedPhase = phase;
        pendingId = "";
        if (completedPhase === "complete") {
            reset();
            return;
        }
        if (completedPhase === "prepare" && data && data.decision === "suppressed") {
            fail("Automatic portal launch already attempted. Use Sign in to retry manually.");
            return;
        }
        if (!data || !validIntent(data.intent)) {
            fail("Portal intent is invalid or expired. Use Sign in to retry manually.");
            return;
        }
        if (completedPhase === "prepare") {
            intent = data.intent;
            send("claim", NmApi.methods.network_portalClaim, {launch_id: intent.launch_id});
        } else if (completedPhase === "claim") {
            if (!intent || data.intent.launch_id !== intent.launch_id || data.intent.episode !== intent.episode || data.intent.url !== intent.url) {
                fail("Portal intent changed. Use Sign in to retry manually.");
                return;
            }
            intent = data.intent;
            phase = "executing";
            controller.status = "Opening captive portal page…";
            backend.executePortal(intent, workspaceId);
        }
    }
    function finished(launchId, outcome) {
        if (phase !== "executing" || !intent || launchId !== intent.launch_id)
            return;
        controller.status = outcome === "opened" ? "Portal browser opened" : (outcome === "failed" ? "Could not start portal browser. Use Sign in to retry." : "Portal launch outcome is unknown. Use Sign in to retry manually.");
        send("complete", NmApi.methods.network_portalComplete, {launch_id: launchId, outcome: outcome});
    }
    function transportLost() {
        // A browser may already exist. Forget this UI transaction, not the
        // daemon's durable attempt. The old process cannot acknowledge a new one.
        reset();
    }
}
