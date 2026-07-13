import QtQuick
import "Wifi.js" as Wifi

Item {
    property bool open: false
    property string mode: ""
    property string title: ""
    property string detail: ""
    property string text: ""
    property bool password: false
    property var network: null
    property string hiddenSsid: ""
    property string enterpriseIdentity: ""
    property string secretRequestId: ""
    property string secretPrimaryKey: ""
    property var secretKeys: []
    property bool saveSecret: false
    property bool saveSecretSupported: false

    function openPrompt(nextMode, nextTitle, nextDetail, nextPassword, nextNetwork, nextHiddenSsid) {
        network = nextNetwork || null;
        hiddenSsid = nextHiddenSsid || "";
        mode = nextMode;
        title = nextTitle;
        detail = nextDetail;
        text = "";
        password = nextPassword;
        saveSecret = false;
        saveSecretSupported = false;
        open = true;
    }

    function promptMessage(ap, fallback) { return ap && ap.connect_prompt && ap.connect_prompt.message ? ap.connect_prompt.message : fallback; }

    function openPasswordPrompt(ap, detailOverride) {
        openPrompt("network-password", "Password for " + Wifi.networkName(ap), detailOverride || promptMessage(ap, "Enter the Wi-Fi password, then press Enter."), true, ap, "");
    }

    function openHiddenNetworkPrompt() {
        openPrompt("hidden-ssid", "Connect hidden network", "Enter the hidden SSID, then press Enter.", false, null, "");
    }

    function openHiddenPasswordPrompt(ssid) {
        openPrompt("hidden-password", "Password for hidden network", "Enter the password for " + ssid + ", or leave blank for an open network.", true, null, ssid);
    }

    function openEnterpriseIdentityPrompt(ap) {
        const note = "Enter your enterprise Wi-Fi identity.";
        openPrompt("enterprise-identity", "Enterprise identity for " + Wifi.networkName(ap), promptMessage(ap, note), false, ap, "");
    }

    function openEnterprisePasswordPrompt(ap, identity) {
        enterpriseIdentity = identity;
        openPrompt("enterprise-password", "Enterprise password for " + identity, "Enter your enterprise Wi-Fi password, then press Enter.", true, ap, "");
    }

    function secretKeyLabel(key) {
        const labels = {
            "psk": "Wi-Fi password",
            "wep-key0": "WEP key",
            "wep-key1": "WEP key",
            "wep-key2": "WEP key",
            "wep-key3": "WEP key",
            "leap-password": "LEAP password",
            "password": "password",
            "private-key-password": "private key password",
            "pin": "PIN"
        };
        return labels[key] || (key ? key.replace(/-/g, " ") : "secret");
    }

    function openDaemonSecretPrompt(event) {
        const keys = event.secret_keys || [];
        const primary = event.primary_secret_key || (keys.length > 0 ? keys[0] : "password");
        const label = secretKeyLabel(primary);
        const setting = event.setting_name ? (" for " + event.setting_name) : "";
        const detailText = "NetworkManager requested " + label + setting + ". Requested keys: " + (keys.length > 0 ? keys.join(", ") : primary) + ".";
        secretRequestId = event.request_id || "";
        secretPrimaryKey = primary;
        secretKeys = keys;
        openPrompt("daemon-secret", "Enter " + label, detailText, primary !== "pin", null, "");
        saveSecretSupported = !!event.save_supported;
    }

    function cancel() {
        open = false;
        text = "";
        mode = "";
        network = null;
        hiddenSsid = "";
        enterpriseIdentity = "";
        secretRequestId = "";
        secretPrimaryKey = "";
        secretKeys = [];
        saveSecret = false;
        saveSecretSupported = false;
    }

    function submitNetworkPassword(controller, value) {
        if (!controller.beginAnyConnectAction())
            return;
        if (value.length === 0)
            return controller.status = "Enter a password for this network.";
        const ap = network;
        const retryDelay = controller.retryDelayRemainingMs(ap, value);
        if (retryDelay > 0)
            return controller.status = "Waiting " + Math.ceil(retryDelay / 1000) + "s before retrying; NetworkManager is temporarily ignoring this AP.";
        cancel();
        if (ap)
            controller.runConnectTarget(ap, Wifi.networkName(ap), value);
    }

    function submitHiddenSsid(controller, value) {
        if (value.length === 0)
            return controller.status = "Enter an SSID for the hidden network.";
        openHiddenPasswordPrompt(value);
    }

    function submitHiddenPassword(controller, value) {
        if (!controller.beginAnyConnectAction())
            return;
        const ssid = hiddenSsid;
        const pass = value.length > 0 ? value : null;
        cancel();
        controller.runConnectTarget({ ssid: ssid, ssid_bytes: [], hidden: true, security: pass !== null ? "WPA" : "--", key_mgmt: pass !== null ? "wpa-psk" : "open" }, ssid, pass);
    }

    function submitEnterpriseIdentity(controller, value) {
        if (value.length === 0)
            return controller.status = "Enter an enterprise Wi-Fi identity.";
        if (network)
            openEnterprisePasswordPrompt(network, value);
    }

    function submitEnterprisePassword(controller, value) {
        if (!controller.beginAnyConnectAction())
            return;
        if (value.length === 0)
            return controller.status = "Enter an enterprise Wi-Fi password.";
        const ap = network;
        const identity = enterpriseIdentity;
        cancel();
        if (ap && identity.length > 0)
            controller.runConnectTarget(Wifi.enterpriseTarget(ap, identity), Wifi.networkName(ap), value);
    }

    function submitDaemonSecret(controller, value) {
        if (value.length === 0)
            return controller.status = "Enter the requested " + secretKeyLabel(secretPrimaryKey) + ".";
        const requestId = secretRequestId;
        const key = secretPrimaryKey;
        const save = saveSecret;
        cancel();
        if (requestId.length > 0)
            controller.provideSecret(requestId, key, value, save);
    }

    function submit(controller) {
        const handlers = {
            "daemon-secret": submitDaemonSecret,
            "enterprise-identity": submitEnterpriseIdentity,
            "enterprise-password": submitEnterprisePassword,
            "hidden-password": submitHiddenPassword,
            "hidden-ssid": submitHiddenSsid,
            "network-password": submitNetworkPassword
        };
        if (handlers[mode])
            handlers[mode](controller, text);
    }
}
