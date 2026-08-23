import QtQuick
import QtTest
import "../../wifi/WifiFlow.js" as Flow

TestCase {
    name: "WifiPrompt"

    property var prompt
    property var capturedSecrets
    property var capturedConnect
    property var fakeController: ({})

    function initTestCase() {
        const component = Qt.createComponent(Qt.resolvedUrl("../../wifi/WifiPromptController.qml"));
        compare(component.status, Component.Ready, component.errorString());
        prompt = component.createObject(null);
        verify(prompt !== null);
        fakeController = {
            status: "",
            connection: {
                beginAny: function () { return true; },
                provideSecrets: function (id, values, save) {
                    capturedSecrets = { id: id, values: values, save: save };
                    return true;
                },
                runTarget: function (target, name, password, identity, enterprise, wepKeyType) {
                    capturedConnect = {
                        target: target, name: name, password: password,
                        enterprise: enterprise, wepKeyType: wepKeyType
                    };
                    return true;
                }
            }
        };
    }

    function cleanupTestCase() { if (prompt) prompt.destroy(); }
    function init() {
        capturedSecrets = null;
        capturedConnect = null;
        prompt.cancel();
    }

    function test_mergesIncrementalNetworkChanges() {
        const current = [{ key: "keep", strength: 10 }, { key: "change", strength: 20 },
            { key: "remove", strength: 30 }];
        const merged = Flow.mergeNetworkChanges(current, {
            removed: [{ key: "remove" }],
            changed: [{ key: "change", strength: 80 }],
            added: [{ key: "add", strength: 40 }, { ssid: "Hidden" }]
        });

        compare(merged.length, 4);
        compare(merged[0].key, "keep");
        compare(merged[1].strength, 80);
        compare(merged[2].key, "add");
        compare(merged[3].ssid, "Hidden");
    }

    function test_submitsEveryRequestedSecret() {
        prompt.openDaemonSecretPrompt({
            request_id: "secret-1",
            setting_name: "802-1x",
            secret_keys: ["password", "private-key-password"],
            primary_secret_key: "password",
            save_supported: true
        });
        compare(prompt.credentialFields.length, 2);
        prompt.saveSecret = true;
        verify(prompt.submitCredentials(fakeController, {
            password: "login-secret",
            "private-key-password": "key-secret"
        }));
        compare(capturedSecrets.id, "secret-1");
        compare(capturedSecrets.values.password, "login-secret");
        compare(capturedSecrets.values["private-key-password"], "key-secret");
        verify(capturedSecrets.save);
    }

    function test_hiddenInvalidSecurityKeepsFormOpen() {
        prompt.openHiddenNetworkPrompt();
        verify(!prompt.submitCredentials(fakeController, {
            ssid: "Hidden Cafe",
            security: "automatic",
            password: ""
        }));
        verify(prompt.credentialOpen);
        verify(capturedConnect === null);
    }

    function test_hiddenSecurityAndWepTypeAreExplicit() {
        prompt.openHiddenNetworkPrompt();
        verify(prompt.submitCredentials(fakeController, {
            ssid: "Hidden Cafe",
            security: "wep-phrase",
            password: "passphrase",
            "enterprise.eap": "peap",
            "enterprise.identity": "",
            "enterprise.phase2_auth": "mschapv2"
        }));
        compare(capturedConnect.target.key_mgmt, "wep");
        compare(capturedConnect.wepKeyType, "phrase");
        compare(capturedConnect.target.ssid, "Hidden Cafe");
    }

    function test_enterpriseFormUsesDaemonSchema() {
        const ap = {
            ssid: "Corp",
            key: "network-key",
            connect_prompt: {
                required_fields: ["enterprise.eap", "enterprise.identity"],
                optional_fields: ["password", "enterprise.domain_suffix_match"],
                enterprise_defaults: { eap: ["ttls"], phase2_auth: "pap" }
            }
        };
        prompt.openEnterpriseIdentityPrompt(ap);
        compare(prompt.credentialValues["enterprise.eap"], "ttls");
        verify(prompt.submitCredentials(fakeController, {
            "enterprise.eap": "ttls",
            "enterprise.identity": "person@example.test",
            "enterprise.domain_suffix_match": "example.test",
            password: "secret"
        }));
        compare(capturedConnect.enterprise.eap[0], "ttls");
        compare(capturedConnect.enterprise.identity, "person@example.test");
        compare(capturedConnect.enterprise.domain_suffix_match, "example.test");
    }
}
