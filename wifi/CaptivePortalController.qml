import QtQuick
import "NmApi.js" as NmApi

// UI transaction only: policy, identity, URL selection and durable attempts live
// in nm-daemon. Never recover/replay a launch command after transport loss.
Item {
    required property WifiController controller
    required property WifiBackend backend

    property string phase: ""
    property string pendingId: ""
    property string workspaceId: ""
    property var intent: null
    readonly property bool busy: phase.length > 0

    function reset(): void {
        pendingId = "";
        phase = "";
        intent = null;
        workspaceId = "";
    }
    function fail(message: string): void {
        reset();
        controller.status = message;
    }
    function send(kind: string, method: string, params: var): bool {
        pendingId = backend.nextRequestId("portal-" + kind);
        phase = kind;
        return backend.call(pendingId, method, params);
    }
    function begin(mode: string, requestId: string, workspace: string, fallback: bool): bool {
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
    function launchForConnect(requestId: string, workspace: string): bool {
        return begin("automatic", requestId, workspace, false);
    }
    function launchManual(workspace: string, fallback: bool): bool {
        return begin("manual", "", workspace, fallback);
    }
    function validIntent(value: var): bool {
        return !!value && typeof value.launch_id === "string" && value.launch_id.length > 0
            && typeof value.episode === "string" && typeof value.url === "string"
            && Number.isFinite(value.expires_at_ms) && value.expires_at_ms > Date.now();
    }
    function receive(id: string, envelope: var, transportError: string): void {
        if (!pendingId || id !== pendingId || !["prepare", "claim", "complete"].includes(phase))
            return;
        const error = backend.responseError(envelope, transportError, "Portal request failed");
        if (error.length > 0) {
            fail(error + ". Use Sign in to retry manually.");
            return;
        }
        const data = envelope.data?.portal;
        const completedPhase = phase;
        pendingId = "";
        if (completedPhase === "complete") {
            reset();
            return;
        }
        if (completedPhase === "prepare" && data?.decision === "suppressed") {
            fail("Automatic portal launch already attempted. Use Sign in to retry manually.");
            return;
        }
        const next = data?.intent;
        if (!validIntent(next)) {
            fail("Portal intent is invalid or expired. Use Sign in to retry manually.");
            return;
        }
        if (completedPhase === "prepare") {
            intent = next;
            send("claim", NmApi.methods.network_portalClaim, {launch_id: intent.launch_id});
            return;
        }
        // Only an owned claim can reach execution. All immutable identity
        // fields must match the prepared intent, not just its launch ID.
        if (!["launch_id", "episode", "url"].every(key => next[key] === intent?.[key])) {
            fail("Portal intent changed. Use Sign in to retry manually.");
            return;
        }
        intent = next;
        phase = "executing";
        controller.status = "Opening captive portal page…";
        backend.executePortal(intent, workspaceId);
    }
    function finished(launchId: string, outcome: string): void {
        if (phase !== "executing" || !intent || launchId !== intent.launch_id)
            return;
        controller.status = outcome === "opened" ? "Portal browser opened" : (outcome === "failed" ? "Could not start portal browser. Use Sign in to retry." : "Portal launch outcome is unknown. Use Sign in to retry manually.");
        send("complete", NmApi.methods.network_portalComplete, {launch_id: launchId, outcome: outcome});
    }
    function transportLost(): void {
        // A browser may already exist. Forget this UI transaction, not the
        // daemon's durable attempt. The old process cannot acknowledge a new one.
        reset();
    }
}
