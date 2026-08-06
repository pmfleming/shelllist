import QtQuick
import "WifiPresentation.js" as Presentation
import "WifiPromptPolicy.js" as Policy

Item {
    id: root

    property bool open: false
    property string mode: ""
    property string title: ""
    property string detail: ""
    property string text: ""
    property bool password: false
    property var network: null
    property string secretRequestId: ""
    property bool saveSecret: false
    property bool saveSecretSupported: false

    property bool credentialOpen: false
    property string credentialMode: ""
    property string credentialTitle: ""
    property string credentialDetail: ""
    property var credentialFields: []
    property var credentialValues: ({})
    property var credentialNetwork: null

    readonly property var submitHandlerByMode: ({
        "confirm-forget": function (controller, value) { root.submitForget(controller, value); },
        "network-password": function (controller, value) { root.submitNetworkPassword(controller, value); }
    })

    function openPrompt(nextMode, nextTitle, nextDetail, nextPassword, nextNetwork) {
        network = nextNetwork || null;
        mode = nextMode;
        title = nextTitle;
        detail = nextDetail;
        text = "";
        password = nextPassword;
        saveSecret = false;
        saveSecretSupported = false;
        open = true;
    }

    function promptMessage(ap, fallback) {
        return ap && ap.connect_prompt && ap.connect_prompt.message ? ap.connect_prompt.message : fallback;
    }

    function openPasswordPrompt(ap, detailOverride) {
        openPrompt("network-password", "Password for " + Presentation.networkName(ap),
            detailOverride || promptMessage(ap, "Enter the Wi-Fi password, then press Enter."), true, ap);
    }

    function openCredentials(nextMode, nextTitle, nextDetail, fields, nextNetwork) {
        credentialMode = nextMode;
        credentialTitle = nextTitle;
        credentialDetail = nextDetail;
        credentialFields = fields;
        credentialValues = Policy.initialValues(fields);
        credentialNetwork = nextNetwork || null;
        credentialOpen = true;
    }

    function openHiddenNetworkPrompt() {
        openCredentials("hidden", "Connect hidden network",
            "Choose security explicitly. Optional enterprise fields may be left blank.", Policy.hiddenFields(), null);
    }

    function openEnterpriseIdentityPrompt(ap) {
        openCredentials("enterprise", "Enterprise credentials for " + Presentation.networkName(ap),
            promptMessage(ap, "Enter the fields required by this enterprise network."), Policy.enterpriseFields(ap), ap);
    }

    function openForgetPrompt(ap, active, profiles) {
        const copy = Policy.forgetCopy(Presentation.networkName(ap), active, profiles);
        openPrompt("confirm-forget", copy.title, copy.detail, false, ap);
    }

    function openDaemonSecretPrompt(event) {
        const spec = Policy.daemonSecretSpec(event);
        secretRequestId = event.request_id || "";
        saveSecretSupported = !!event.save_supported;
        openCredentials("daemon-secret", "Network credentials", spec.detail, spec.fields, null);
    }

    function cancel() {
        open = false;
        credentialOpen = false;
        credentialMode = "";
        credentialFields = [];
        credentialValues = ({});
        credentialNetwork = null;
        text = "";
        mode = "";
        network = null;
        secretRequestId = "";
        saveSecret = false;
        saveSecretSupported = false;
    }

    function submitNetworkPassword(controller, value) {
        if (!controller.connection.beginAny()) return;
        if (value.length === 0) {
            controller.status = "Enter a password for this network.";
            return;
        }
        const ap = network;
        const retryDelay = controller.connectPolicy.retryDelayRemainingMs(ap, value);
        if (retryDelay > 0) {
            controller.status = "Waiting " + Math.ceil(retryDelay / 1000)
                + "s before retrying; NetworkManager is temporarily ignoring this AP.";
            return;
        }
        cancel();
        if (ap) controller.connection.runTarget(ap, Presentation.networkName(ap), value);
    }

    function submitCredentials(controller, values) {
        const validationError = Policy.validationError(credentialMode, credentialFields, values);
        if (validationError.length > 0) {
            controller.status = validationError;
            return false;
        }
        if (!controller.connection.beginAny()) return false;

        const nextMode = credentialMode;
        const ap = credentialNetwork;
        const requestId = secretRequestId;
        const save = saveSecret;
        cancel();
        if (nextMode === "daemon-secret")
            return controller.connection.provideSecrets(requestId, values, save);

        const request = Policy.connectionRequest(nextMode, ap, values);
        const name = nextMode === "hidden" ? String(values.ssid || "") : Presentation.networkName(ap);
        return controller.connection.runTarget(request.target, name, request.password, null,
            request.enterprise, request.wepKeyType);
    }

    function submitForget(controller, value) {
        if (value.trim().toLowerCase() !== "forget") {
            controller.status = "Type FORGET to confirm removing this network.";
            return;
        }
        const ap = network;
        cancel();
        if (ap) controller.actions.executeForget(ap);
    }

    function submit(controller) {
        const handler = submitHandlerByMode[mode];
        if (handler) handler(controller, text);
    }
}
