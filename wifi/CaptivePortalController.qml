import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow

Item {
    required property WifiController controller
    required property WifiBackend backend

    function context(trigger, ap, result, requestId, workspaceId, automatic, fallback) {
        const identity = Flow.portalNetworkIdentity(ap, result || ({}));
        const connectivity = Flow.portalConnectivity(result, controller.connection.connectivity, controller.activeStatus);
        return {
            trigger: trigger,
            ssid: Presentation.valueOr(result, "ssid", Presentation.networkName(ap)),
            identity: identity,
            episode: Flow.portalEpisode(automatic, identity, requestId),
            connectivity: Presentation.valueOr(connectivity, "state", "unknown"),
            // NetworkManager's own probe URL and the connection it probed. The
            // browser opens the URL NetworkManager actually tested rather than
            // a guessed one, and the banner names the right connection on a
            // machine with several.
            checkUri: Flow.portalCheckUri(connectivity),
            primaryConnection: Flow.portalPrimaryConnection(connectivity),
            requestId: requestId,
            workspaceId: workspaceId,
            automatic: automatic,
            fallback: fallback
        };
    }

    function launch(portalContext) {
        console.info("shelllist portal trigger=" + portalContext.trigger
            + " ssid=" + portalContext.ssid
            + " identity=" + portalContext.identity
            + " connectivity=" + portalContext.connectivity
            + " check_uri=" + (portalContext.checkUri.length > 0 ? portalContext.checkUri : "none")
            + " primary=" + (portalContext.primaryConnection.length > 0 ? portalContext.primaryConnection : "unknown")
            + " request_id=" + portalContext.requestId
            + " workspace=" + portalContext.workspaceId);
        controller.status = "Opening captive portal page…";
        backend.openPortal(portalContext);
    }

    function launchForConnect(ap, result, requestId, workspaceId) {
        launch(context("connect-result", ap, result, requestId, workspaceId, true, false));
    }

    function launchManual(ap, workspaceId) {
        launch(context("manual", ap, null, "", workspaceId, false, false));
    }
}
