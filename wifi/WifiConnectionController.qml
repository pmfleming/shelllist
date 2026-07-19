import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api

Item {
    id: connection

    required property var controller
    required property var backend
    required property var prompt
    required property var policy
    required property var portal
    property var connectivity: null
    property string networkName: ""
    property int progressTick: 0
    property string workspaceId: ""
    property string requestId: ""
    readonly property bool running: backend.connectStarting || requestId.length > 0

    function activate() { if (running) progressTimer.restart(); }
    function deactivate() { if (!running) progressTimer.stop(); }
    function canBeginAny() { return !backend.running; }
    function canBegin(ap) { return canBeginAny() && !!(ap && ap.capabilities && ap.capabilities.can_connect); }
    function beginAny() { return controller.requireIdle(canBeginAny()); }
    function begin(ap) { return controller.requireIdle(canBegin(ap)); }
    function isConnecting(ap) { return running && networkName.length > 0 && Presentation.networkName(ap) === networkName && !controller.isActive(ap); }
    function networkIsActive() { return networkName.length > 0 && Presentation.networkName(controller.activeAccessPoint()) === networkName; }
    function updateVisibleProgress() {
        if (!running || !networkIsActive()) return;
        controller.setHeldStatus("Wi-Fi link established with " + networkName + "; checking internet access…", 2500);
        progressTimer.stop();
    }
    function resetProgress() { networkName = ""; progressTick = 0; progressTimer.stop(); }

    function finishEvent(event, succeeded) {
        const completedRequestId = event.request_id || requestId;
        requestId = ""; resetProgress();
        applyResult(Api.connectEventResult(event), event.message || (succeeded ? "Connected" : "Connection failed"), completedRequestId);
        if (succeeded) controller.refresh();
    }
    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId)) return;
        if (event.event === "cancelled") {
            requestId = ""; resetProgress();
            controller.setHeldStatus(event.message || "Connection cancelled", 2500); controller.refresh(); return;
        }
        const state = Api.connectEventState(event);
        if (state === "progress") { controller.setBackgroundStatus(event.message || "Connecting to " + networkName + "…"); return; }
        finishEvent(event, state === "succeeded");
    }
    function applyConnectivityEvent(event) {
        if (event.event !== "changed") return;
        const previous = connectivity;
        connectivity = event.connectivity || null;
        if (!previous || !Presentation.connectivityRequiresSignIn(previous)) return;
        if (!connectivity || (!connectivity.full && connectivity.state !== "full")) return;
        const active = controller.activeAccessPoint();
        controller.setHeldStatus("Connected to " + (active ? Presentation.networkName(active) : "Wi-Fi") + " with internet access", 2500);
    }

    function deferForPrompt(ap) {
        if (policy.secretStale(ap)) { prompt.openPasswordPrompt(ap, "Saved password failed. Enter a new Wi-Fi password."); return true; }
        const promptKind = ap && ap.connect_prompt ? (ap.connect_prompt.kind || "none") : "none";
        const handlers = { password: function () { prompt.openPasswordPrompt(ap); }, enterprise: function () { prompt.openEnterpriseIdentityPrompt(ap); } };
        if (handlers[promptKind]) { handlers[promptKind](); return true; }
        if (ap && ap.capabilities && ap.capabilities.can_connect) return false;
        controller.status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs."; return true;
    }
    function connect(ap) {
        if (!ap || !begin(ap)) return false;
        if (!deferForPrompt(ap)) runTarget(ap, Presentation.networkName(ap));
        return true;
    }
    function targetRequest(ap, password, enterpriseIdentity) {
        const request = ap.key ? { key: ap.key } : { target: ap };
        if (password !== undefined && password !== null) request.password = password;
        if (enterpriseIdentity) request.enterprise_identity = enterpriseIdentity;
        return request;
    }
    function runTarget(ap, displayName, password, enterpriseIdentity) {
        const attemptKey = Flow.connectAttemptKey(ap);
        const secretFingerprint = Flow.passwordFingerprint(password);
        if (running && policy.lastConnectAttemptKey === attemptKey && policy.lastConnectSecretFingerprint === secretFingerprint) {
            controller.status = "Connection attempt for " + displayName + " is already running…"; return;
        }
        const retryDelay = policy.retryDelayRemainingMs(ap, password);
        if (retryDelay > 0) {
            controller.status = "Waiting " + Math.ceil(retryDelay / 1000) + "s before retrying " + displayName + "; NetworkManager is temporarily ignoring this AP."; return;
        }
        policy.rememberConnectAttempt(ap, password); run(targetRequest(ap, password, enterpriseIdentity), displayName);
    }
    function run(request, displayName) {
        if (!controller.requireIdle(!backend.nonConnectRunning)) return;
        controller.status = running ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectivity = ({ state: "unknown", captive_portal: false, full: false });
        networkName = displayName; workspaceId = controller.currentWorkspaceId; progressTick = 0; progressTimer.restart();
        backend.connect(request);
    }
    function applyResult(result, fallbackText, completedRequestId) {
        const message = result.message || fallbackText || "Wi-Fi connection failed";
        if (result.status === "error") { controller.status = message; handleConnectError(result); }
        else { policy.clearSecretStale(policy.lastConnectAp); controller.invalidateShareAvailabilityCache(); controller.setHeldStatus(message, 2500); }
        if (Flow.confirmedPortalResult(result)) portal.launchForConnect(policy.lastConnectAp, result, completedRequestId || "", workspaceId);
        controller.maybeRunPendingRefresh();
    }
    function handleConnectError(result) {
        if (!Flow.isSecretFailureReason(result.reason)) return;
        policy.markSecretStale(policy.lastConnectAp); policy.blockLastConnectRetry(Flow.connectFailureRetryMs(result.reason));
        if (policy.lastConnectAp) prompt.openPasswordPrompt(policy.lastConnectAp, Flow.isWrongPasswordReason(result.reason)
            ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
    }
    function provideSecret(id, key, password, save) { controller.status = "Sending requested Wi-Fi secret to NetworkManager…"; backend.provideSecret(id, key, password, save); }
    function cancelSecret(id) { backend.cancelSecret(id); }
    function cancel() {
        if (requestId.length === 0) { controller.status = "Waiting for the connection request to become cancellable…"; return; }
        controller.status = "Cancelling connection to " + networkName + "…"; backend.cancel(requestId);
    }

    Timer { id: progressTimer; interval: 120; repeat: true; onTriggered: connection.progressTick += 1 }
}
