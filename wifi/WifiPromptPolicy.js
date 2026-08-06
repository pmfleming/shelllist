.pragma library

const hiddenSecurityModes = ["open", "owe", "wpa-psk", "sae", "wep-key", "wep-phrase", "wpa-eap"];
const passwordSecurityModes = ["wpa-psk", "sae", "wep-key", "wep-phrase"];
const keyManagement = {
    "open": "open", "owe": "owe", "wpa-psk": "wpa-psk", "sae": "sae",
    "wep-key": "wep", "wep-phrase": "wep", "wpa-eap": "wpa-eap"
};
const enterpriseLabels = {
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
const secretLabels = {
    "psk": "Wi-Fi password", "wep-key0": "WEP key", "wep-key1": "WEP key",
    "wep-key2": "WEP key", "wep-key3": "WEP key", "leap-password": "LEAP password",
    "password": "Password", "private-key-password": "Private key password", "pin": "PIN"
};

function field(key, label, required, password, value) {
    return { key: key, label: label, required: required, password: password, value: value || "" };
}

function hiddenFields() {
    return [
        field("ssid", "Network name (SSID)", true, false, ""),
        field("security", "Security: open, owe, wpa-psk, sae, wep-key, wep-phrase, or wpa-eap", true, false, "wpa-psk"),
        field("password", "Password / key", false, true, ""),
        field("enterprise.eap", "EAP methods (comma-separated)", false, false, "peap"),
        field("enterprise.identity", "Enterprise identity", false, false, ""),
        field("enterprise.anonymous_identity", "Anonymous identity", false, false, ""),
        field("enterprise.phase2_auth", "Inner authentication", false, false, "mschapv2"),
        field("enterprise.ca_cert", "CA certificate path", false, false, "")
    ];
}

function initialValues(fields) {
    const values = ({});
    fields.forEach(function (item) { values[item.key] = item.value || ""; });
    return values;
}

function enterpriseLabel(key) {
    return enterpriseLabels[key] || key.replace(/^enterprise\./, "").replace(/_/g, " ");
}

function enterpriseFields(ap) {
    const prompt = ap.connect_prompt || ({});
    const defaults = prompt.enterprise_defaults || ({});
    const required = prompt.required_fields || ["enterprise.eap", "enterprise.identity"];
    const keys = required.concat(prompt.optional_fields || ["password"])
        .filter(function (key, index, values) { return values.indexOf(key) === index; });
    return keys.map(function (key) {
        const name = key.replace(/^enterprise\./, "");
        const defaultValue = key === "enterprise.eap" ? (defaults.eap || ["peap"]).join(",")
            : (defaults[name] === undefined || defaults[name] === null ? "" : String(defaults[name]));
        return field(key, enterpriseLabel(key), required.includes(key),
            key === "password" || key.includes("password") || key === "enterprise.pin", defaultValue);
    });
}

function forgetCopy(networkName, active, profiles) {
    const names = (profiles || []).map(function (profile) { return profile.id; });
    const profileText = names.length === 0 ? "no saved profile is currently listed"
        : names.length + " saved profile" + (names.length === 1 ? "" : "s") + ": " + names.join(", ");
    return {
        title: (active ? "Disconnect & forget " : "Forget ") + networkName,
        detail: (active ? "Disconnect from this network and remove " : "Remove ") + profileText
            + ". The hotspot may still recognize this device until its login session expires. Type FORGET to confirm."
    };
}

function secretLabel(key) {
    return secretLabels[key] || (key ? key.replace(/-/g, " ") : "Secret");
}

function daemonSecretSpec(event) {
    const keys = event.secret_keys && event.secret_keys.length > 0
        ? event.secret_keys : [event.primary_secret_key || "password"];
    const setting = event.setting_name ? " for " + event.setting_name : "";
    return {
        detail: "NetworkManager requested " + keys.map(secretLabel).join(", ") + setting + ".",
        fields: keys.map(function (key) { return field(key, secretLabel(key), true, key !== "pin", ""); })
    };
}

function enterpriseObject(values) {
    const enterprise = ({});
    Object.keys(values).filter(function (key) {
        return key.indexOf("enterprise.") === 0 && String(values[key]).length > 0;
    }).forEach(function (key) {
        const name = key.slice("enterprise.".length);
        enterprise[name] = name === "eap"
            ? String(values[key]).split(",").map(function (item) { return item.trim(); }).filter(Boolean)
            : values[key];
    });
    return enterprise;
}

function validationError(mode, fields, values) {
    const missing = fields.find(function (item) { return item.required && !String(values[item.key] || "").trim(); });
    if (missing) return "Complete required field: " + missing.label;
    if (mode !== "hidden") return "";
    const security = String(values.security || "").toLowerCase();
    if (!hiddenSecurityModes.includes(security)) return "Choose a supported hidden-network security value.";
    if (passwordSecurityModes.includes(security) && !String(values.password || "").length)
        return "Enter the password or key required by this hidden network.";
    if (security === "wpa-eap" && !String(values["enterprise.identity"] || "").length)
        return "Enter the identity required by this hidden enterprise network.";
    return "";
}

function connectionRequest(mode, network, values) {
    const enterprise = mode === "enterprise" || String(values.security).toLowerCase() === "wpa-eap"
        ? enterpriseObject(values) : null;
    if (mode === "enterprise") {
        return { target: network, password: values.password || null, enterprise: enterprise, wepKeyType: null };
    }
    const ssid = String(values.ssid || "");
    const security = String(values.security || "").toLowerCase();
    return {
        target: {
            ssid: ssid, ssid_bytes: [], hidden: true,
            security: security === "open" ? "--" : (security === "owe" ? "OWE" : "WPA2/3"),
            key_mgmt: keyManagement[security], enterprise: enterprise
        },
        password: values.password || null,
        enterprise: enterprise,
        wepKeyType: security === "wep-phrase" ? "phrase" : (security === "wep-key" ? "key" : null)
    };
}
