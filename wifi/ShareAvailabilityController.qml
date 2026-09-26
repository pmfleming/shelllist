import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiFlow.js" as Flow
import "NmApiClient.js" as Api

Item {
    required property WifiController controller
    required property WifiBackend backend

    property bool available: false
    property string profilePath: ""
    property string requestKey: ""
    property int requestGeneration: -1
    property string status: unavailableMessage
    readonly property string unavailableMessage: "Wi-Fi QR sharing is not available for this network."

    function canShareSelected() {
        return available && !backend.isPending("share");
    }
    function reset() {
        available = false;
        profilePath = "";
        status = unavailableMessage;
    }
    function invalidate() {
        controller.qr.close();
        reset();
    }
    function refresh() {
        if (controller.qr.open && (!controller.detailAp || controller.detailAp.key !== requestKey))
            controller.qr.close();
        if (!controller.hasSelection)
            return reset();
        // Metadata only: never fetch/cache a credential just to enable a button.
        const hint = Flow.shareHint(controller.detailAp);
        profilePath = hint.profile_path || (controller.profileFor(controller.detailAp) || {}).path || "";
        available = !!hint.shareable || (!!hint.requires_profile_secret_check && profilePath.length > 0);
        status = available ? "Request Wi-Fi sharing" : (hint.reason || unavailableMessage);
    }
    function showSelected() {
        if (!canShareSelected())
            return controller.status = status;
        controller.qr.begin(Presentation.networkName(controller.detailAp));
        requestKey = controller.detailAp.key;
        requestGeneration = controller.qr.generation;
        const sent = profilePath.length > 0 ? backend.share(profilePath) : backend.renderShare(Flow.wifiQrPayload(controller.detailAp));
        if (!sent)
            fail("Could not request Wi-Fi sharing");
    }
    function copySelected() {
        // Fetch credentials only following explicit intent; copying is then an
        // explicit action in the share dialog, not from an availability cache.
        showSelected();
    }
    function isCurrent() {
        return controller.qr.open && controller.qr.generation === requestGeneration && controller.detailAp && controller.detailAp.key === requestKey;
    }
    function applyResponse(response, errorText) {
        if (!isCurrent())
            return;
        try {
            const result = Api.apiData(response, "result");
            if (result.path && result.path !== profilePath)
                return fail("Wi-Fi profile changed; request sharing again");
            if (!result.shareable || !result.qr_svg)
                return fail(result.reason || errorText || unavailableMessage);
            controller.qr.show(result);
        } catch (error) {
            fail(errorText || "Could not prepare Wi-Fi sharing");
        }
    }
    function fail(message) {
        if (isCurrent())
            controller.qr.error = message;
    }
}
