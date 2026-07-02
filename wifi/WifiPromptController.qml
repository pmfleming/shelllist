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

    function openPrompt(nextMode, nextTitle, nextDetail, nextPassword, nextNetwork, nextHiddenSsid) {
        network = nextNetwork || null;
        hiddenSsid = nextHiddenSsid || "";
        mode = nextMode;
        title = nextTitle;
        detail = nextDetail;
        text = "";
        password = nextPassword;
        open = true;
    }

    function openPasswordPrompt(ap) {
        openPrompt("network-password", "Password for " + Wifi.networkName(ap), "Enter the Wi-Fi password, then press Enter.", true, ap, "");
    }

    function openHiddenNetworkPrompt() {
        openPrompt("hidden-ssid", "Connect hidden network", "Enter the hidden SSID, then press Enter.", false, null, "");
    }

    function openHiddenPasswordPrompt(ssid) {
        openPrompt("hidden-password", "Password for hidden network", "Enter the password for " + ssid + ", or leave blank for an open network.", true, null, ssid);
    }

    function openEnterpriseIdentityPrompt(ap) {
        const auth = ap && ap.auth ? ap.auth : ({});
        const note = "Enter your enterprise Wi-Fi identity. Shelllist will use PEAP/MSCHAPv2 defaults for now.";
        openPrompt("enterprise-identity", "Enterprise identity for " + Wifi.networkName(ap), auth.note || note, false, ap, "");
    }

    function openEnterprisePasswordPrompt(ap, identity) {
        enterpriseIdentity = identity;
        openPrompt("enterprise-password", "Enterprise password for " + identity, "Enter your enterprise Wi-Fi password, then press Enter.", true, ap, "");
    }

    function cancel() {
        open = false;
        text = "";
        mode = "";
        network = null;
        hiddenSsid = "";
        enterpriseIdentity = "";
    }

    function submitNetworkPassword(controller, value) {
        if (!controller.beginAnyConnectAction())
            return;
        if (value.length === 0)
            return controller.status = "Enter a password for this network.";
        const ap = network;
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
        const args = Wifi.nmApiArgs("wifi", "connect", ssid, "--hidden");
        if (pass !== null)
            args.push("--password-stdin");
        controller.runConnect(args, ssid, pass);
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

    function submit(controller) {
        const handlers = {
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
