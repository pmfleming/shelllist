import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api
import "NmApi.js" as NmApi

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
    property string recoveryId: ""
    property string recoveryRequestId: ""
    property int recoveryFailures: 0
    property bool cancellationRequested: false
    readonly property bool running: backend.connectStarting || requestId.length > 0

    function activate() {
        if (running)
            progressTimer.restart();
    }
    function deactivate() {
        if (!running)
            progressTimer.stop();
    }
    function canBeginAny() {
        return !backend.running && controller.bandRequestId.length === 0;
    }
    function canBegin(ap) {
        return canBeginAny() && !!(ap && ap.capabilities && ap.capabilities.can_connect);
    }
    function beginAny() {
        return controller.requireIdle(canBeginAny());
    }
    function begin(ap) {
        return controller.requireIdle(canBegin(ap));
    }
    function keyFor(ap) {
        return ap && ap.key ? ap.key : "";
    }
    function isConnecting(ap) {
        return running && networkKey.length > 0 && keyFor(ap) === networkKey;
    }
    function networkIsActive() {
        return networkKey.length > 0 && controller.activeNetworkKey() === networkKey;
    }
    function updateVisibleProgress() {
        if (!running || !networkIsActive())
            return;
        controller.setHeldStatus("Wi-Fi link established with " + networkName + "; waiting for operation confirmation…", 2500);
        progressTimer.stop();
    }
    function resetProgress() {
        networkName = "";
        networkKey = "";
        progressTick = 0;
        progressTimer.stop();
    }
    function handleTransportFailure() {
        retireRecovery();
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
        requestId = "";
        resetProgress();
        applyResult(Api.connectEventResult(event), event.message || (succeeded ? "Connected" : "Connection failed"), completedRequestId);
        if (succeeded)
            controller.refresh();
    }
    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId))
            return;
        if (event.event === "cancelled") {
            requestId = "";
            resetProgress();
            controller.setHeldStatus(event.message || "Connection cancelled", 2500);
            controller.refresh();
            return;
        }
        const state = Api.connectEventState(event);
        if (state === "progress") {
            controller.setHeldStatus(event.message || "Connecting to " + networkName + "…", 15000);
            return;
        }
        finishEvent(event, state === "succeeded");
    }
    function applyConnectivityEvent(event) {
        if (event.event !== "changed")
            return;
        const previous = connectivity;
        connectivity = event.connectivity || null;
        if (!previous || !Presentation.connectivityRequiresSignIn(previous))
            return;
        if (!connectivity || (!connectivity.full && connectivity.state !== "full"))
            return;
        const active = controller.activeAccessPoint();
        controller.setHeldStatus("Connected to " + (active ? Presentation.networkName(active) : "Wi-Fi") + " with internet access", 2500);
    }

    function deferForPrompt(ap) {
        const promptKind = ap && ap.connect_prompt ? (ap.connect_prompt.kind || "none") : "none";
        const handlers = {
            password: function () {
                prompt.openPasswordPrompt(ap);
            },
            enterprise: function () {
                prompt.openEnterpriseIdentityPrompt(ap);
            }
        };
        if (handlers[promptKind]) {
            handlers[promptKind]();
            return true;
        }
        if (ap && ap.capabilities && ap.capabilities.can_connect)
            return false;
        controller.status = "This access point cannot be connected from Shelllist yet. Use F6 for hidden SSIDs.";
        return true;
    }
    function connect(ap) {
        if (!ap || !begin(ap))
            return false;
        if (!deferForPrompt(ap))
            runTarget(ap, Presentation.networkName(ap));
        return true;
    }
    function targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType) {
        const request = ap.key ? {
            key: ap.key
        } : {
            target: ap
        };
        if (password !== undefined && password !== null)
            request.password = password;
        if (enterpriseIdentity)
            request.enterprise_identity = enterpriseIdentity;
        if (enterprise)
            request.enterprise = enterprise;
        if (wepKeyType)
            request.wep_key_type = wepKeyType;
        return request;
    }
    function runTarget(ap, displayName, password, enterpriseIdentity, enterprise, wepKeyType) {
        lastConnectAp = ap;
        run(targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType), displayName);
    }
    function run(request, displayName) {
        if (!controller.requireIdle(!backend.nonConnectRunning))
            return;
        controller.status = running ? "Connection attempt already running…" : "Connecting to " + displayName + "…";
        connectivity = ({
                state: "unknown",
                captive_portal: false,
                full: false
            });
        networkName = displayName;
        networkKey = request.key || ((request.target || {}).key || "");
        workspaceId = controller.currentWorkspaceId;
        progressTick = 0;
        progressTimer.restart();
        if (!backend.connect(request)) {
            console.error("shelllist wifi connection rejected stage=dispatch network=" + displayName);
            resetProgress();
            controller.status = "Could not start the connection request for " + displayName + ".";
        }
    }
    function applyResult(result, fallbackText, completedRequestId) {
        const message = result.message || fallbackText || "Wi-Fi connection failed";
        if (result.status === "error") {
            controller.status = message;
            handleConnectError(result);
        } else {
            controller.invalidateShareAvailabilityCache();
            controller.setHeldStatus(message, 2500);
        }
        if (result && result.suggest_open_portal)
            portal.launchForConnect(completedRequestId || "", workspaceId);
        controller.maybeRunPendingRefresh();
    }
    function handleConnectError(result) {
        if (!Flow.isSecretFailureReason(result.reason))
            return;
        if (lastConnectAp)
            prompt.openPasswordPrompt(lastConnectAp, Flow.isWrongPasswordReason(result.reason) ? "Wrong password. Enter a new Wi-Fi password." : "Saved password failed. Enter a new Wi-Fi password.");
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
        if (requestId.length === 0) {
            controller.status = "Waiting for the connection request to become cancellable…";
            return;
        }
        controller.status = "Cancelling connection to " + networkName + "…";
        cancellationRequested = true;
        if (!backend.cancel(requestId)) {
            cancellationRequested = false;
            controller.status = "Could not cancel the connection to " + networkName + ".";
        }
        recoveryTimer.restart();
    }

    function retireRecovery() {
        if (recoveryId.length > 0)
            backend.setPending(recoveryId, false);
        recoveryId = "";
        recoveryRequestId = "";
        recoveryReplyTimer.stop();
    }
    function checkStatus(manual) {
        if (!requestId || recoveryId)
            return false;
        if (manual)
            recoveryFailures = 0;
        recoveryTimer.stop();
        recoveryRequestId = requestId;
        recoveryId = backend.nextRequestId("connection-status");
        recoveryReplyTimer.restart();
        return backend.call(recoveryId, NmApi.methods.operation_status, {request_id: requestId});
    }
    function recoveryFailed(message) {
        retireRecovery();
        recoveryFailures += 1;
        controller.setHeldStatus(message + " Connection outcome is unconfirmed; use Check status or Cancel.", 15000);
        if (requestId && recoveryFailures < 3)
            recoveryTimer.restart();
    }
    function receiveStatus(id, envelope, transportError) {
        if (!recoveryId || id !== recoveryId || recoveryRequestId !== requestId)
            return;
        const error = backend.responseError(envelope, transportError, "Could not check connection status.");
        if (error) {
            recoveryFailed(error);
            return;
        }
        const result = (envelope.data || ({})).result;
        if (!result || result.request_id !== requestId || result.stream !== NmApi.streams.wifi_connect || !["running", "finished"].includes(result.status)) {
            recoveryFailed("The daemon could not confirm this connection operation.");
            return;
        }
        const event = result.event;
        if (result.status === "finished" && (!event || event.request_id !== requestId || !["succeeded", "failed", "cancelled"].includes(event.event))) {
            recoveryFailed("The daemon returned an invalid connection result.");
            return;
        }
        retireRecovery();
        recoveryFailures = 0;
        if (result.status === "finished") {
            handleEvent(event);
            return;
        }
        // A progress snapshot is not completion, even if wifi.status is active.
        if (event && event.request_id === requestId && ["started", "progress"].includes(event.event))
            handleEvent(event);
        if (result.cancellation_requested) {
            cancellationRequested = true;
            controller.setHeldStatus(result.timed_out ? "Connection timed out; waiting for cancellation acknowledgement…" : "Waiting for connection cancellation acknowledgement…", 15000);
        }
        recoveryTimer.restart();
    }
    onRequestIdChanged: {
        retireRecovery();
        recoveryFailures = 0;
        cancellationRequested = false;
        if (requestId.length > 0)
            recoveryTimer.restart();
        else
            recoveryTimer.stop();
    }
    Timer {
        id: recoveryTimer
        interval: 15000
        onTriggered: connection.checkStatus(false)
    }
    Timer {
        id: recoveryReplyTimer
        interval: 10000
        onTriggered: connection.recoveryFailed("Connection status check timed out.")
    }
    Timer {
        id: progressTimer
        interval: 120
        repeat: true
        onTriggered: connection.progressTick += 1
    }
}
