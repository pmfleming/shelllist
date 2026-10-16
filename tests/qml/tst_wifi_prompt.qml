import QtQuick
import QtTest

TestCase {
    id: testCase
    name: "WifiPrompt"
    width: 640
    height: 480
    when: windowShown
    visible: true

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
                beginAny: function () {
                    return true;
                },
                provideSecrets: function (id, values, save) {
                    capturedSecrets = {
                        id: id,
                        values: values,
                        save: save
                    };
                    return true;
                },
                runTarget: function (target, name, password, identity, enterprise, wepKeyType, remember) {
                    capturedConnect = {
                        target: target,
                        name: name,
                        password: password,
                        enterprise: enterprise,
                        wepKeyType: wepKeyType,
                        remember: remember
                    };
                    return true;
                }
            }
        };
    }

    function cleanupTestCase() {
        if (prompt)
            prompt.destroy();
    }
    function init() {
        capturedSecrets = null;
        capturedConnect = null;
        prompt.cancel();
    }

    function test_submitsEveryRequestedSecret() {
        prompt.openDaemonSecretPrompt({
            request_id: "secret-1",
            data: {
                setting_name: "802-1x",
                secret_keys: ["password", "private-key-password"],
                primary_secret_key: "password",
                save_supported: true
            }
        });
        compare(prompt.credentialFields.length, 2);
        verify(prompt.saveSecret, "remember defaults on for each supported request");
        verify(prompt.saveSecretRequired, "legacy backends cannot promise save:false is temporary");
        verify(prompt.submitCredentials(fakeController, {
            password: "login-secret",
            "private-key-password": "key-secret"
        }));
        compare(capturedSecrets.id, "secret-1");
        compare(capturedSecrets.values.password, "login-secret");
        compare(capturedSecrets.values["private-key-password"], "key-secret");
        verify(capturedSecrets.save);
    }

    function test_rememberIsExplicitOptOutAndResetsForNewRequests() {
        const network = {ssid: "Cafe", key: "cafe"};
        prompt.openPasswordPrompt(network);
        verify(prompt.saveSecret);
        prompt.saveSecret = false;
        prompt.text = "test-password";
        prompt.submit(fakeController);
        compare(capturedConnect.password, "test-password");
        compare(capturedConnect.remember, false);
        prompt.openPasswordPrompt(network);
        verify(prompt.saveSecret, "opt-out is local to this connection intent");
        prompt.cancel();
        prompt.openDaemonSecretPrompt({request_id: "temporary", data: {secret_keys: ["psk"], save_supported: false}});
        verify(!prompt.saveSecret, "temporary native credentials must not be saved");
        verify(prompt.submitCredentials(fakeController, {psk: "test-password"}));
        verify(!capturedSecrets.save);
    }

    function test_nativeRequiredStorageCannotBeUncheckedAndEscapeCancels() {
        prompt.openDaemonSecretPrompt({request_id: "native", data: {
            secret_keys: ["psk"], save_supported: true, save_required: true,
            storage_provider: "networkmanager"
        }});
        const component = Qt.createComponent(Qt.resolvedUrl("../../wifi/WifiCredentialDialog.qml"));
        compare(component.status, Component.Ready, component.errorString());
        const dialog = createTemporaryObject(component, testCase, {prompt: prompt, width: 640, height: 480});
        verify(dialog !== null);
        dialog.cancelled.connect(function () { prompt.cancel(); });
        const remember = findChild(dialog, "rememberCredentials");
        verify(remember !== null);
        verify(remember.visible && remember.checked);
        verify(!remember.enabled);
        mouseClick(remember);
        verify(prompt.saveSecret, "a disabled remember control cannot promise use-once");
        prompt.saveSecret = false; // controller must also reject a programmatic downgrade
        verify(!prompt.submitCredentials(fakeController, {psk: "synthetic-test-only"}));
        verify(capturedSecrets === null);
        dialog.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        verify(!prompt.credentialOpen);
        compare(Object.keys(prompt.credentialValues).length, 0);
        verify(capturedSecrets === null);
    }

    function test_agentOwnedRequestDoesNotOfferImplicitMigration() {
        prompt.openDaemonSecretPrompt({request_id: "legacy", data: {
            secret_keys: ["psk"], save_supported: false, save_required: false,
            migration_required: true, storage_provider: "networkmanager"
        }});
        verify(!prompt.saveSecret && !prompt.saveSecretRequired);
        verify(prompt.credentialDetail.indexOf("explicit migration") >= 0);
        verify(prompt.submitCredentials(fakeController, {psk: "synthetic-test-only"}));
        verify(!capturedSecrets.save);
    }

    function test_mixedOwnershipRequiresMigrationRatherThanAnImpossibleSaveChoice() {
        prompt.openDaemonSecretPrompt({request_id: "mixed", data: {
            secret_keys: ["password", "private-key-password"],
            save_supported: false, save_required: true, migration_required: true
        }});
        verify(prompt.credentialDetail.indexOf("Mixed credential ownership") >= 0);
        verify(!prompt.submitCredentials(fakeController, {password: "synthetic", "private-key-password": "synthetic"}));
        verify(capturedSecrets === null);
    }

    function test_validatesHiddenAndEnterpriseSchema() {
        prompt.openHiddenNetworkPrompt(null);
        verify(!prompt.credentialOpen, "missing native descriptors must fail closed");
        prompt.openHiddenNetworkPrompt({
            fields: [{key: "ssid", required: true, password: false, value: ""},
                {key: "security", required: true, password: false, value: "wep-phrase"},
                {key: "password", required: false, password: true, value: ""}],
            security_modes: [{id: "wep-phrase", security: "WEP", key_mgmt: "wep", wep_key_type: "phrase",
                enterprise: false, required_fields: ["password"]}]
        });
        verify(!prompt.submitCredentials(fakeController, {
            ssid: "Hidden Cafe",
            security: "automatic",
            password: ""
        }));
        verify(prompt.credentialOpen);
        verify(capturedConnect === null);

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

        prompt.openEnterpriseIdentityPrompt({
            ssid: "Corp",
            key: "network-key",
            connect_prompt: {
                required_fields: ["enterprise.eap", "enterprise.identity"],
                optional_fields: ["password", "enterprise.domain_suffix_match"],
                enterprise_defaults: {
                    eap: ["ttls"],
                    phase2_auth: "pap"
                }
            }
        });
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
