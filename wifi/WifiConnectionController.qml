import QtQuick
import "WifiPresentation.js" as Presentation
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
    property bool recoveryTimedOut: false
    property double operationRevision: 0
    property bool cancellationRequested: false
    // Only unsaved connection intentions are local. Existing profiles always
    // reflect NM's acknowledged retention, including pending deletion.
    property var rememberChoices: ({})
    readonly property bool rememberNetwork: rememberFor(controller.detailAp)
    readonly property bool canSetRemember: !controller.actionInFlight && !!controller.detailAp?.key
        && (controller.profileFor(controller.detailAp)
            ? typeof controller.profileFor(controller.detailAp).remember === "boolean"
            : !controller.detailAp.active)
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
    function rememberFor(ap) {
        const profile = controller.profileFor(ap);
        if (profile)
            return profile.remember !== false;
        return rememberChoices[keyFor(ap)] === true;
    }
    function setRemember(enabled) {
        if (!canSetRemember)
            return false;
        const ap = controller.detailAp;
        const profile = controller.profileFor(ap);
        if (profile) {
            controller.status = "Updating network retention…";
            return backend.profile({operation: "set-remember", path: profile.path, enabled: enabled});
        }
        const choices = Object.assign({}, rememberChoices);
        choices[keyFor(ap)] = enabled;
        rememberChoices = choices;
        controller.setHeldStatus(enabled
            ? "Network details will be saved for future connections."
            : "Network details won't be saved. Future connections won't be remembered.", 6000);
        return true;
    }
    function observeProfiles(networks) {
        const choices = Object.assign({}, rememberChoices);
        for (const ap of networks) {
            if (controller.profileFor(ap))
                delete choices[keyFor(ap)];
        }
        rememberChoices = choices;
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
        applyResult(Api.connectEventResult(event), event.data.message || (succeeded ? "Connected" : "Connection failed"), completedRequestId);
        if (succeeded)
            controller.refresh();
    }
    function eventError(event) {
        if (!event || event.request_id !== requestId || event.stream !== NmApi.streams.wifi_connect
                || !["started", "progress", "succeeded", "failed", "cancelled"].includes(event.event)
                || !event.data || typeof event.data !== "object" || Array.isArray(event.data))
            return "The daemon returned an invalid connection event.";
        if (!Number.isSafeInteger(event.operation_revision) || event.operation_revision < 1)
            return "Missing native connection revision; matching nm-daemon required.";
        const result = event.data.result;
        if (result !== undefined && result !== null && (typeof result !== "object" || Array.isArray(result)))
            return "The daemon returned an invalid connection outcome.";
        if ((event.event === "succeeded" && (!result || result.status !== "connected"))
                || (event.event === "failed" && result && result.status !== "error"))
            return "The daemon returned an invalid connection outcome.";
        return "";
    }
    function handleEvent(event) {
        if (!Api.requestMatches(event, requestId))
            return;
        const error = eventError(event);
        if (error) {
            controller.setHeldStatus(error + " Connection outcome is unconfirmed; use Check status or Cancel.", 15000);
            return;
        }
        if (event.operation_revision <= operationRevision)
            return;
        operationRevision = event.operation_revision;
        if (event.event === "cancelled") {
            requestId = "";
            resetProgress();
            controller.setHeldStatus(event.data.message || "Connection cancelled", 2500);
            controller.refresh();
            return;
        }
        const state = Api.connectEventState(event);
        if (state === "progress") {
            if (cancellationRequested)
                return;
            controller.setHeldStatus(event.data.message || "Connecting to " + networkName + "…", 15000);
            return;
        }
        finishEvent(event, state === "succeeded");
    }
    function applyConnectivityEvent(event) {
        if (event.event !== "changed")
            return;
        const previous = connectivity;
        connectivity = event.data.connectivity || null;
        if (!previous || !Presentation.connectivityRequiresSignIn(previous))
            return;
        if (!connectivity || (!connectivity.full && connectivity.state !== "full"))
            return;
        const active = controller.activeAccessPoint();
        controller.setHeldStatus("Connected to " + (active ? Presentation.networkName(active) : "Wi-Fi") + " with internet access", 2500);
    }

    function deferForPrompt(ap) {
        // Saved-profile activation owns credential discovery. Even a stale
        // prompt descriptor must not turn ordinary Connect into replacement.
        if (controller.profileFor(ap))
            return false;
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
            prompt.saveSecret = rememberFor(ap);
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
    function targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType, remember) {
        const request = ap.key ? {
            key: ap.key
        } : {
            target: ap
        };
        request.remember = remember === undefined ? rememberFor(ap) : remember !== false;
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
    function runTarget(ap, displayName, password, enterpriseIdentity, enterprise, wepKeyType, remember) {
        lastConnectAp = ap;
        run(targetRequest(ap, password, enterpriseIdentity, enterprise, wepKeyType, remember), displayName);
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
            handleConnectError(result, message);
        } else {
            controller.invalidateShareAvailabilityCache();
            controller.setHeldStatus(message, 2500);
        }
        if (result && result.suggest_open_portal)
            portal.launchForConnect(completedRequestId || "", workspaceId);
        controller.maybeRunPendingRefresh();
    }
    function handleConnectError(result, fallbackText) {
        // Failure is not permission to start another credential transaction.
        // NM's outstanding SecretAgent request owns re-prompts; after it ends,
        // reconnecting or editing the saved password requires explicit user action.
        controller.status = result.message || result.recovery_prompt?.message || fallbackText || "Wi-Fi connection failed";
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
        recoveryTimedOut = false;
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
    function statusTimedOut() {
        if (!recoveryId || recoveryRequestId !== requestId)
            return;
        // A deadline is not cancellation of the transport read. Retain its
        // identity/admission until reply or owner loss; never overlap polls.
        recoveryTimedOut = true;
        recoveryTimer.stop();
        controller.setHeldStatus("Connection status check timed out. Outcome is unconfirmed; waiting for the outstanding read or Cancel.", 15000);
    }
    function receiveStatus(id, envelope, transportError) {
        if (!recoveryId || id !== recoveryId || recoveryRequestId !== requestId)
            return;
        const failure = backend.responseError(envelope, transportError, "Could not check connection status.");
        const result = envelope?.data?.result;
        const error = failure || statusError(result);
        if (error) {
            recoveryFailed(error);
            return;
        }
        applyStatus(result);
    }
    function statusError(result) {
        if (!result || result.request_id !== requestId || result.stream !== NmApi.streams.wifi_connect || !["running", "finished"].includes(result.status))
            return "The daemon could not confirm this connection operation.";
        if (!Number.isSafeInteger(result.operation_revision) || result.operation_revision < 1)
            return "Missing native connection revision; matching nm-daemon required.";
        const event = result.event;
        if (event) {
            const error = eventError(event);
            if (error)
                return error;
            // eventError already restricts the native event vocabulary. Reuse
            // the live-event phase classification rather than a second table.
            const terminalEvent = Api.connectEventState(event) !== "progress";
            if (event.operation_revision !== result.operation_revision
                    || (result.status === "finished") !== terminalEvent)
                return "The daemon returned an invalid connection result.";
        } else if (result.status === "finished" || result.operation_revision !== 1) {
            return "The daemon returned an invalid connection result.";
        }
        return "";
    }
    function applyStatus(result) {
        const event = result.event;
        retireRecovery();
        recoveryFailures = 0;
        if (result.status === "finished") {
            handleEvent(event);
            if (requestId)
                recoveryTimer.restart(); // An older terminal cannot release newer work.
            return;
        }
        // A progress snapshot is not completion, even if wifi.status is active.
        // Cancellation is monotone: an older read cannot revoke local intent.
        cancellationRequested = cancellationRequested || result.cancellation_requested === true;
        if (event)
            handleEvent(event);
        else
            operationRevision = Math.max(operationRevision, result.operation_revision);
        if (cancellationRequested) {
            controller.setHeldStatus(result.timed_out ? "Connection timed out; waiting for cancellation acknowledgement…" : "Waiting for connection cancellation acknowledgement…", 15000);
        }
        recoveryTimer.restart();
    }
    onRequestIdChanged: {
        retireRecovery();
        recoveryFailures = 0;
        operationRevision = 0;
        cancellationRequested = false;
        if (requestId.length > 0)
            recoveryTimer.restart();
        else
            recoveryTimer.stop();
    }
    Timer {
        id: recoveryTimer
        objectName: "connectionRecoveryPoll"
        interval: 15000
        onTriggered: connection.checkStatus(false)
    }
    Timer {
        id: recoveryReplyTimer
        objectName: "connectionRecoveryReplyDeadline"
        interval: 10000
        onTriggered: connection.statusTimedOut()
    }
    Timer {
        id: progressTimer
        interval: 120
        repeat: true
        onTriggered: connection.progressTick += 1
    }
}
