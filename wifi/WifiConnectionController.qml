import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api

Item {
    id: connection

    required property WifiController controller
    required property WifiBackend backend
    required property WifiPromptController prompt
    required property CaptivePortalController portal
    property var connectivity: null
    property string networkName: ""
    property string networkKey: ""
    property int progressTick: 0
    property string workspaceId: ""
    property string requestId: ""
    property var lastConnectAp: null
    readonly property bool running: backend.connectStarting || requestId.length > 0

    function activate() { if (running) progressTimer.restart(); }
    function deactivate() { if (!running) progressTimer.stop(); }
    function canBeginAny() { return !backend.running; }
    function canBegin(ap) { return canBeginAny() && !!(ap && ap.capabilities && ap.capabilities.can_connect); }
    function beginAny() { return controller.requireIdle(canBeginAny()); }
    function begin(ap) { return controller.requireIdle(canBegin(ap)); }
    function keyFor(ap) { return ap && ap.key ? ap.key : ""; }
    function isConnecting(ap) { return running && networkKey.length > 0 && keyFor(ap) === networkKey && !controller.isActive(ap); }
    function networkIsActive() { return networkKey.length > 0 && controller.activeNetworkKey() === networkKey; }
    function updateVisibleProgress() {
        if (!running || !networkIsActive()) return;
        controller.setHeldStatus("Wi-Fi link established with " + networkName + "; checking internet access…", 2500);
        progressTimer.stop();
    }
    function resetProgress() { networkName = ""; networkKey = ""; progressTick = 0; progressTimer.stop(); }
    function handleTransportFailure() {
        const lostRequestId = requestId;
        requestId = "";
        resetProgress();
        connectivity = null;
        lastConnectAp = null;
        if (lostRequestId.length > 0)
            console.warn("shelllist wifi connection discarded reason=transport-failure request_id=" + lostRequestId);
    }

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
    function targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType) {
        const request = ap.key ? { key: ap.key } : { target: ap };
        if (password !== undefined && password !== null) request.password = password;
        if (enterpriseIdentity) request.enterprise_identity = enterpriseIdentity;
        if (enterprise) request.enterprise = enterprise;
        if (wepKeyType) request.wep_key_type = wepKeyType;
        return request;
    }
    function runTarget(ap, displayName, password, enterpriseIdentity, enterprise, wepKeyType) {
        lastConnectAp = ap;
        run(targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType), displayName);
    }
    function run(request, displayName) {
        if (!controller.requireIdle(!backend.nonConnectRunning)) return;
        controller.status = running ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectivity = ({ state: "unknown", captive_portal: false, full: false });
        networkName = displayName;
        networkKey = request.key || ((request.target || {}).key || "");
        workspaceId = controller.currentWorkspaceId; progressTick = 0; progressTimer.restart();
        if (!backend.connect(request)) {
            console.error("shelllist wifi connection rejected stage=dispatch network=" + displayName);
            resetProgress();
            controller.status = "Could not start the connection request for " + displayName + ".";
        }
    }
    function applyResult(result, fallbackText, completedRequestId) {
        const message = result.message || fallbackText || "Wi-Fi connection failed";
        if (result.status === "error") { controller.status = message; handleConnectError(result); }
        else { controller.invalidateShareAvailabilityCache(); controller.setHeldStatus(message, 2500); }
        if (Flow.confirmedPortalResult(result)) portal.launchForConnect(lastConnectAp, result, completedRequestId || "", workspaceId);
        controller.maybeRunPendingRefresh();
    }
    function handleConnectError(result) {
        if (!Flow.isSecretFailureReason(result.reason)) return;
        if (lastConnectAp) prompt.openPasswordPrompt(lastConnectAp, Flow.isWrongPasswordReason(result.reason)
            ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
    }
    function provideSecrets(id, values, save) {
        controller.status = "Sending requested Wi-Fi credentials to NetworkManager…";
        if (!backend.provideSecrets(id, values, save)) {
            console.error("shelllist wifi secrets rejected stage=dispatch request_id=" + id);
            controller.status = "Could not send the requested Wi-Fi credentials to NetworkManager.";
            return false;
        }
        return true;
    }
    function cancelSecret(id) {
        if (!backend.cancelSecret(id)) {
            console.error("shelllist wifi secret cancellation rejected request_id=" + id);
            return false;
        }
        return true;
    }
    function cancel() {
        if (requestId.length === 0) { controller.status = "Waiting for the connection request to become cancellable…"; return; }
        controller.status = "Cancelling connection to " + networkName + "…";
        if (!backend.cancel(requestId))
            controller.status = "Could not cancel the connection to " + networkName + ".";
    }

    Timer { id: progressTimer; interval: 120; repeat: true; onTriggered: connection.progressTick += 1 }
}
