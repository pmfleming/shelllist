import QtQuick
import "WifiPresentation.js" as Presentation

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

    // Complex NetworkManager authentication is represented as named fields
    // instead of flattening every request into one password string.
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
        return ap && ap.connect_prompt && ap.connect_prompt.message
            ? ap.connect_prompt.message : fallback;
    }

    function openPasswordPrompt(ap, detailOverride) {
        openPrompt("network-password", "Password for " + Presentation.networkName(ap),
            detailOverride || promptMessage(ap, "Enter the Wi-Fi password, then press Enter."), true, ap);
    }

    function field(key, label, required, passwordField, value) {
        return {
            key: key,
            label: label,
            required: required,
            password: passwordField,
            value: value || ""
        };
    }

    function openCredentials(nextMode, nextTitle, nextDetail, fields, nextNetwork) {
        credentialMode = nextMode;
        credentialTitle = nextTitle;
        credentialDetail = nextDetail;
        credentialFields = fields;
        credentialValues = ({});
        fields.forEach(function (item) { credentialValues[item.key] = item.value || ""; });
        credentialNetwork = nextNetwork || null;
        credentialOpen = true;
    }

    function openHiddenNetworkPrompt() {
        openCredentials("hidden", "Connect hidden network",
            "Choose security explicitly. Optional enterprise fields may be left blank.", [
                field("ssid", "Network name (SSID)", true, false, ""),
                field("security", "Security: open, owe, wpa-psk, sae, wep-key, wep-phrase, or wpa-eap", true, false, "wpa-psk"),
                field("password", "Password / key", false, true, ""),
                field("enterprise.eap", "EAP methods (comma-separated)", false, false, "peap"),
                field("enterprise.identity", "Enterprise identity", false, false, ""),
                field("enterprise.anonymous_identity", "Anonymous identity", false, false, ""),
                field("enterprise.phase2_auth", "Inner authentication", false, false, "mschapv2"),
                field("enterprise.ca_cert", "CA certificate path", false, false, "")
            ], null);
    }

    function enterpriseFieldLabel(key) {
        const labels = {
            "enterprise.eap": "EAP methods (comma-separated)",
            "enterprise.identity": "Identity",
            "password": "Password",
            "enterprise.anonymous_identity": "Anonymous identity",
            "enterprise.phase2_auth": "Inner authentication",
            "enterprise.ca_cert": "CA certificate path",
            "enterprise.domain_suffix_match": "Server domain suffix",
            "enterprise.client_cert": "Client certificate path",
            "enterprise.private_key": "Private key path",
            "enterprise.private_key_password": "Private key password"
        };
        return labels[key] || key.replace(/^enterprise\./, "").replace(/_/g, " ");
    }

    function openEnterpriseIdentityPrompt(ap) {
        const prompt = ap.connect_prompt || ({});
        const defaults = prompt.enterprise_defaults || ({});
        const required = prompt.required_fields || ["enterprise.eap", "enterprise.identity"];
        const optional = prompt.optional_fields || ["password"];
        const fields = required.concat(optional).filter(function (key, index, values) {
            return values.indexOf(key) === index;
        }).map(function (key) {
            let value = "";
            const name = key.replace(/^enterprise\./, "");
            if (key === "enterprise.eap")
                value = (defaults.eap || ["peap"]).join(",");
            else if (defaults[name] !== undefined && defaults[name] !== null)
                value = String(defaults[name]);
            return field(key, enterpriseFieldLabel(key), required.indexOf(key) >= 0,
                key === "password" || key.indexOf("password") >= 0 || key === "enterprise.pin", value);
        });
        openCredentials("enterprise", "Enterprise credentials for " + Presentation.networkName(ap),
            promptMessage(ap, "Enter the fields required by this enterprise network."), fields, ap);
    }

    function openForgetPrompt(ap, active, profiles) {
        const names = (profiles || []).map(function (profile) { return profile.id; });
        const profileText = names.length === 0 ? "no saved profile is currently listed"
            : (names.length + " saved profile" + (names.length === 1 ? "" : "s") + ": " + names.join(", "));
        const action = active ? "Disconnect from this network and remove " : "Remove ";
        const portalNote = " The hotspot may still recognize this device until its login session expires.";
        openPrompt("confirm-forget",
            active ? "Disconnect & forget " + Presentation.networkName(ap) : "Forget " + Presentation.networkName(ap),
            action + profileText + "." + portalNote + " Type FORGET to confirm.", false, ap);
    }

    function secretKeyLabel(key) {
        const labels = {
            "psk": "Wi-Fi password", "wep-key0": "WEP key", "wep-key1": "WEP key",
            "wep-key2": "WEP key", "wep-key3": "WEP key", "leap-password": "LEAP password",
            "password": "Password", "private-key-password": "Private key password", "pin": "PIN"
        };
        return labels[key] || (key ? key.replace(/-/g, " ") : "Secret");
    }

    function openDaemonSecretPrompt(event) {
        const keys = event.secret_keys && event.secret_keys.length > 0
            ? event.secret_keys : [event.primary_secret_key || "password"];
        const setting = event.setting_name ? (" for " + event.setting_name) : "";
        secretRequestId = event.request_id || "";
        saveSecretSupported = !!event.save_supported;
        openCredentials("daemon-secret", "Network credentials",
            "NetworkManager requested " + keys.map(secretKeyLabel).join(", ") + setting + ".",
            keys.map(function (key) {
                return field(key, secretKeyLabel(key), true, key !== "pin", "");
            }), null);
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
        if (!controller.connection.beginAny())
            return;
        if (value.length === 0)
            return controller.status = "Enter a password for this network.";
        const ap = network;
        const retryDelay = controller.connectPolicy.retryDelayRemainingMs(ap, value);
        if (retryDelay > 0)
            return controller.status = "Waiting " + Math.ceil(retryDelay / 1000) + "s before retrying; NetworkManager is temporarily ignoring this AP.";
        cancel();
        if (ap)
            controller.connection.runTarget(ap, Presentation.networkName(ap), value);
    }

    function enterpriseObject(values) {
        const enterprise = ({});
        Object.keys(values).forEach(function (key) {
            if (key.indexOf("enterprise.") !== 0 || String(values[key]).length === 0)
                return;
            const name = key.slice("enterprise.".length);
            enterprise[name] = name === "eap"
                ? String(values[key]).split(",").map(function (item) { return item.trim(); }).filter(Boolean)
                : values[key];
        });
        return enterprise;
    }

    function submitCredentials(controller, values) {
        const missing = credentialFields.filter(function (item) {
            return item.required && !String(values[item.key] || "").trim();
        });
        if (missing.length > 0) {
            controller.status = "Complete required field: " + missing[0].label;
            return false;
        }
        if (credentialMode === "hidden") {
            const security = String(values.security || "").toLowerCase();
            const supported = ["open", "owe", "wpa-psk", "sae", "wep-key", "wep-phrase", "wpa-eap"];
            if (supported.indexOf(security) < 0) {
                controller.status = "Choose a supported hidden-network security value.";
                return false;
            }
            if (["wpa-psk", "sae", "wep-key", "wep-phrase"].indexOf(security) >= 0
                    && !String(values.password || "").length) {
                controller.status = "Enter the password or key required by this hidden network.";
                return false;
            }
            if (security === "wpa-eap" && !String(values["enterprise.identity"] || "").length) {
                controller.status = "Enter the identity required by this hidden enterprise network.";
                return false;
            }
        }
        if (!controller.connection.beginAny())
            return false;
        const nextMode = credentialMode;
        const ap = credentialNetwork;
        const requestId = secretRequestId;
        const save = saveSecret;
        cancel();
        if (nextMode === "daemon-secret")
            return controller.connection.provideSecrets(requestId, values, save);
        if (nextMode === "enterprise") {
            const enterprise = enterpriseObject(values);
            return controller.connection.runTarget(ap, Presentation.networkName(ap),
                values.password || null, null, enterprise);
        }
        if (nextMode === "hidden") {
            const ssid = String(values.ssid || "");
            const security = String(values.security || "").toLowerCase();
            const keyMgmtBySecurity = {
                "open": "open", "owe": "owe", "wpa-psk": "wpa-psk", "sae": "sae",
                "wep-key": "wep", "wep-phrase": "wep", "wpa-eap": "wpa-eap"
            };
            const keyMgmt = keyMgmtBySecurity[security];
            const enterprise = security === "wpa-eap" ? enterpriseObject(values) : null;
            const target = {
                ssid: ssid, ssid_bytes: [], hidden: true,
                security: security === "open" ? "--" : (security === "owe" ? "OWE" : "WPA2/3"),
                key_mgmt: keyMgmt, enterprise: enterprise
            };
            const wepType = security === "wep-phrase" ? "phrase" : (security === "wep-key" ? "key" : null);
            return controller.connection.runTarget(target, ssid, values.password || null, null, enterprise, wepType);
        }
        return false;
    }

    function submitForget(controller, value) {
        if (value.trim().toLowerCase() !== "forget")
            return controller.status = "Type FORGET to confirm removing this network.";
        const ap = network;
        cancel();
        if (ap)
            controller.actions.executeForget(ap);
    }

    function submit(controller) {
        const handler = submitHandlerByMode[mode];
        if (handler)
            handler(controller, text);
    }
}
