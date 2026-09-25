interface PromptField {
    key: string;
    label: string;
    required: boolean;
    password: boolean;
    value: string;
}
type PromptValues = Record<string, string>;
interface ConnectPrompt {
    enterprise_defaults?: Record<string, unknown> & { eap?: string[] };
    required_fields?: string[];
    optional_fields?: string[];
}
interface SecretRequest {
    secret_keys?: string[];
    primary_secret_key?: string;
    setting_name?: string;
}

const hiddenSecurityModes = ["open", "owe", "wpa-psk", "sae", "wep-key", "wep-phrase", "wpa-eap"];
const passwordSecurityModes = ["wpa-psk", "sae", "wep-key", "wep-phrase"];
const keyManagement: Record<string, string> = {
    "open": "open", "owe": "owe", "wpa-psk": "wpa-psk", "sae": "sae",
    "wep-key": "wep", "wep-phrase": "wep", "wpa-eap": "wpa-eap"
};
const enterpriseLabels: Record<string, string> = {
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
const secretLabels: Record<string, string> = {
    "psk": "Wi-Fi password", "wep-key0": "WEP key", "wep-key1": "WEP key",
    "wep-key2": "WEP key", "wep-key3": "WEP key", "leap-password": "LEAP password",
    "password": "Password", "private-key-password": "Private key password", "pin": "PIN"
};

function field(key: string, label: string, required: boolean, password: boolean, value: string): PromptField {
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

function initialValues(fields: PromptField[]) {
    const values: PromptValues = ({});
    fields.forEach(function (item: PromptField) { values[item.key] = item.value || ""; });
    return values;
}

function enterpriseLabel(key: string) {
    return enterpriseLabels[key] || key.replace(/^enterprise\./, "").replace(/_/g, " ");
}

function enterpriseDefault(key: string, defaults: NonNullable<ConnectPrompt["enterprise_defaults"]>) {
    const name = key.replace(/^enterprise\./, "");
    if (key === "enterprise.eap")
        return (defaults.eap || ["peap"]).join(",");
    return defaults[name] === undefined || defaults[name] === null ? "" : String(defaults[name]);
}

function enterpriseSecret(key: string) { return key === "password" || key.includes("password") || key === "enterprise.pin"; }

function enterpriseFields(ap: { connect_prompt?: ConnectPrompt | null }) {
    const prompt: ConnectPrompt = ap.connect_prompt || ({});
    const defaults = prompt.enterprise_defaults || ({});
    const required = prompt.required_fields || ["enterprise.eap", "enterprise.identity"];
    const keys = required.concat(prompt.optional_fields || ["password"])
        .filter(function (key: string, index: number, values: string[]) { return values.indexOf(key) === index; });
    return keys.map(function (key: string) {
        return field(key, enterpriseLabel(key), required.includes(key),
            enterpriseSecret(key), enterpriseDefault(key, defaults));
    });
}

function forgetCopy(networkName: string, active: boolean, profiles: { id: string }[] | null | undefined) {
    const names = (profiles || []).map(function (profile: { id: string }) { return profile.id; });
    const profileText = names.length === 0 ? "no saved profile is currently listed"
        : names.length + " saved profile" + (names.length === 1 ? "" : "s") + ": " + names.join(", ");
    return {
        title: (active ? "Disconnect & forget " : "Forget ") + networkName,
        detail: (active ? "Disconnect from this network and remove " : "Remove ") + profileText
            + ". The hotspot may still recognize this device until its login session expires. Type FORGET to confirm."
    };
}

function secretLabel(key: string) {
    return secretLabels[key] || (key ? key.replace(/-/g, " ") : "Secret");
}

function daemonSecretSpec(event: SecretRequest) {
    const keys = event.secret_keys && event.secret_keys.length > 0
        ? event.secret_keys : [event.primary_secret_key || "password"];
    const setting = event.setting_name ? " for " + event.setting_name : "";
    return {
        detail: "NetworkManager requested " + keys.map(secretLabel).join(", ") + setting + ".",
        fields: keys.map(function (key: string) { return field(key, secretLabel(key), true, key !== "pin", ""); })
    };
}

function enterpriseObject(values: PromptValues) {
    const enterprise: Record<string, string | string[]> = ({});
    Object.keys(values).filter(function (key: string) {
        return key.indexOf("enterprise.") === 0 && String(values[key]).length > 0;
    }).forEach(function (key: string) {
        const name = key.slice("enterprise.".length);
        enterprise[name] = name === "eap"
            ? String(values[key]).split(",").map(function (item: string) { return item.trim(); }).filter(Boolean)
            : values[key];
    });
    return enterprise;
}

function hiddenValidationError(values: PromptValues) {
    const security = String(values.security || "").toLowerCase();
    if (!hiddenSecurityModes.includes(security))
        return "Choose a supported hidden-network security value.";
    if (passwordSecurityModes.includes(security) && !String(values.password || "").length)
        return "Enter the password or key required by this hidden network.";
    if (security === "wpa-eap" && !String(values["enterprise.identity"] || "").length)
        return "Enter the identity required by this hidden enterprise network.";
    return "";
}

function validationError(mode: string, fields: PromptField[], values: PromptValues) {
    const missing = fields.find(function (item: PromptField) {
        return item.required && !String(values[item.key] || "").trim();
    });
    if (missing)
        return "Complete required field: " + missing.label;
    return mode === "hidden" ? hiddenValidationError(values) : "";
}

function hiddenSecurityLabel(security: string) {
    return security === "open" ? "--" : (security === "owe" ? "OWE" : "WPA2/3");
}
function wepKeyType(security: string) {
    return security === "wep-phrase" ? "phrase" : (security === "wep-key" ? "key" : null);
}

function connectionRequest(mode: string, network: unknown, values: PromptValues) {
    const security = String(values.security || "").toLowerCase();
    const enterprise = mode === "enterprise" || security === "wpa-eap" ? enterpriseObject(values) : null;
    if (mode === "enterprise")
        return { target: network, password: values.password || null, enterprise: enterprise, wepKeyType: null };
    return {
        target: {
            ssid: String(values.ssid || ""), ssid_bytes: [], hidden: true,
            security: hiddenSecurityLabel(security), key_mgmt: keyManagement[security], enterprise: enterprise
        },
        password: values.password || null,
        enterprise: enterprise,
        wepKeyType: wepKeyType(security)
    };
}
