import Quickshell
import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api

Item {
    id: share

    required property var controller
    required property var backend

    property bool available: false
    property string payload: ""
    property string profilePath: ""
    property string requestPath: ""
    property int cacheGeneration: 0
    property int requestGeneration: 0
    property var availabilityCache: ({})
    property string status: unavailableMessage
    readonly property string unavailableMessage: "Wi-Fi QR sharing is not available for this network."

    function canShareSelected() { return available && payload.length > 0; }
    function reset() {
        profilePath = "";
        setAvailability(false, "", unavailableMessage);
    }
    function cached(path) { return path.length > 0 ? (availabilityCache[path] || null) : null; }
    function cache(path, isAvailable, qrPayload, message) {
        if (path.length === 0)
            return;
        const updated = Object.assign({}, availabilityCache);
        updated[path] = { available: isAvailable, payload: qrPayload, message: message };
        availabilityCache = updated;
    }
    function invalidate() {
        cacheGeneration += 1;
        availabilityCache = ({});
        reset();
    }
    function refresh() {
        if (!controller.hasSelection)
            return reset();
        const result = Flow.shareAvailability(
            controller.detailAp,
            controller.profileFor(controller.detailAp),
            "Wi-Fi QR sharing requires an open network or a saved profile with a readable password."
        );
        if (result.state !== "check") {
            profilePath = "";
            return setAvailability(result.available, result.payload, result.message);
        }
        profilePath = result.profilePath;
        const cachedResult = cached(result.profilePath);
        if (cachedResult)
            return setAvailability(cachedResult.available, cachedResult.payload, cachedResult.message);
        setAvailability(false, "", "Checking saved Wi-Fi password availability…");
        if (backend.isPending("share"))
            return;
        requestPath = result.profilePath;
        requestGeneration = cacheGeneration;
        if (!backend.share(result.profilePath))
            requestPath = "";
    }
    function copySelected() {
        if (!canShareSelected())
            return controller.status = status;
        Quickshell.clipboardText = payload;
        controller.status = "Wi-Fi QR payload for " + Presentation.networkName(controller.detailAp) + " copied to clipboard";
    }
    function setAvailability(isAvailable, qrPayload, message) {
        available = isAvailable;
        payload = qrPayload;
        status = message;
    }
    function refreshIfOpen() {
        if (controller.detailsOpen)
            Qt.callLater(refresh);
    }
    function applyResult(result, requestedPath, requestedGeneration) {
        if (requestedGeneration !== cacheGeneration)
            return refreshIfOpen();
        const resultPath = result.path || requestedPath;
        cache(resultPath, result.available, result.payload, result.message);
        if (resultPath === profilePath)
            setAvailability(result.available, result.payload, result.message);
        else
            refreshIfOpen();
    }
    function applyFailure(requestedPath, requestedGeneration, message) {
        if (requestedGeneration !== cacheGeneration)
            return refreshIfOpen();
        cache(requestedPath, false, "", message);
        if (requestedPath === profilePath)
            setAvailability(false, "", message);
        else
            refreshIfOpen();
    }
    function applyResponse(response, errorText) {
        const requestedPath = requestPath;
        const requestedGeneration = requestGeneration;
        requestPath = "";
        try {
            applyResult(
                Flow.shareCheckAvailability(Api.apiData(response, "result"), unavailableMessage),
                requestedPath,
                requestedGeneration
            );
        } catch (error) {
            applyFailure(requestedPath, requestedGeneration, "Could not check Wi-Fi QR sharing: " + (errorText || error));
        }
    }
    function fail(message) {
        const failedPath = requestPath;
        requestPath = "";
        applyFailure(failedPath, requestGeneration, "Could not check Wi-Fi QR sharing: " + message);
    }
}
