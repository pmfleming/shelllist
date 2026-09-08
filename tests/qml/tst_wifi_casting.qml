pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Shelllist.Io as Io
import "../../wifi" as Wifi

TestCase {
    id: testCase
    name: "WifiCasting"
    when: windowShown
    visible: true
    width: 720
    height: 760

    property var calls: []
    property var originalFactory
    property var originalSessions

    Component {
        id: clientFactory
        QtObject {
            property string daemonName
            property var streams: []
            property bool active: false
            property bool ready: true
            property bool recoverProtocolErrors: false
            signal response(string id, var envelope, string transportError)
            signal eventReceived(var event)
            signal transportFailed(string message)
            function call(id, method, params) {
                testCase.calls = testCase.calls.concat([{ id: id, method: method, params: params }]);
            }
            function subscribeExtra(id, streams) {}
            function cancel(id, requestId) {}
        }
    }

    function initTestCase() {
        originalFactory = Io.DaemonSessions.clientFactory;
        originalSessions = Io.DaemonSessions.sessions;
        Io.DaemonSessions.sessions = ({});
        Io.DaemonSessions.clientFactory = clientFactory;
    }

    function cleanupTestCase() {
        for (const name of Object.keys(Io.DaemonSessions.sessions))
            Io.DaemonSessions.sessions[name].client.destroy();
        Io.DaemonSessions.sessions = originalSessions;
        Io.DaemonSessions.clientFactory = originalFactory;
    }

    function init() { calls = []; }

    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias page: page
            Wifi.WifiPromptController { id: prompt }
            Wifi.WifiController { id: controller; prompt: prompt }
            Wifi.AdvancedSettingsPage {
                id: page
                anchors.fill: parent
                controller: panel.controller
            }
        }
    }

    function profile(enabled) {
        return {
            path: "/org/freedesktop/NetworkManager/Settings/1",
            version: "saved-version", casting_enabled: enabled,
            mac_address_policy: "stable", send_hostname: false,
            autoconnect: true, metered: "auto", hidden: false,
            security_type: "WPA2 Personal",
            ipv4: { method: "auto" }, ipv6: { method: "auto" }
        };
    }

    function makePanel(enabled) {
        const panel = createTemporaryObject(panelComponent, testCase);
        verify(panel !== null);
        panel.controller.advanced.open = true;
        panel.controller.advanced.profilePath = profile(enabled).path;
        panel.controller.advanced.applyProfile(profile(enabled));
        return panel;
    }

    function test_togglePersistsBothDirections_data() {
        return [{ tag: "enable", initial: false }, { tag: "disable", initial: true }];
    }

    function test_togglePersistsBothDirections(data) {
        const panel = makePanel(data.initial);
        const toggle = findChild(panel, "castingToggle");
        verify(toggle !== null);
        verify(toggle.enabled);
        compare(toggle.checked, data.initial);
        compare(panel.page.settingsPayload().advanced.casting_enabled, undefined,
            "unrelated edits must not rewrite the saved mDNS policy");

        toggle.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(toggle.checked, !data.initial);
        verify(panel.page.securityDirty);
        tryVerify(function () { return testCase.calls.length > 0; });
        const request = calls[0];
        verify(request.id.endsWith("::advanced-save"));
        compare(request.method, "wifi.profile.operation");
        compare(request.params.operation, "update");
        compare(request.params.path, profile(data.initial).path);
        compare(request.params.settings.expected_version, "saved-version");
        compare(request.params.settings.advanced.casting_enabled, !data.initial);
        compare(request.params.settings.mac_address_policy, "stable");
        compare(request.params.settings.send_hostname, false);
        verify(!panel.page.securityDirty);

        panel.controller.backend.setPending("advanced-save", false);
        panel.controller.advanced.applySave({ message: "Saved" });
        compare(calls[1].params.operation, "details");
        panel.controller.advanced.applyProfile(profile(!data.initial));
        compare(toggle.checked, !data.initial);
        compare(panel.page.settingsPayload().advanced.casting_enabled, undefined);
    }

    function test_partialSaveReloadsVersionButKeepsLiveFailureVisible() {
        const panel = makePanel(false);
        panel.page.setCastingEnabled(true);
        panel.page.saveDirty();
        panel.controller.backend.acceptSharedResponse("advanced-save", {
            error: { details: { profile_saved: true, live_applied: false } }
        }, "activation-failed: Profile saved, but live Cast discovery update failed");
        compare(calls[1].params.operation, "details");
        const saved = profile(true);
        saved.version = "new-saved-version";
        panel.controller.backend.setPending("advanced-load", false);
        panel.controller.advanced.applyProfile(saved);
        verify(panel.controller.advanced.error.indexOf("live Cast discovery update failed") >= 0);
        panel.page.setCastingEnabled(false);
        panel.page.saveDirty();
        compare(calls[2].params.settings.expected_version, "new-saved-version");
        compare(calls[2].params.settings.advanced.casting_enabled, false);
    }

    function test_unavailableWhileLoadingOrSavingAndResetsWithProfile() {
        const panel = makePanel(true);
        const toggle = findChild(panel, "castingToggle");
        for (const id of ["advanced-load", "advanced-save"]) {
            panel.controller.backend.setPending(id, true);
            verify(!toggle.enabled);
            panel.page.setCastingEnabled(false);
            verify(panel.page.castingEnabled);
            verify(!panel.page.securityDirty);
            panel.controller.backend.setPending(id, false);
        }
        panel.controller.advanced.profile = ({});
        verify(!toggle.enabled);
        verify(!toggle.checked);
        panel.page.setCastingEnabled(true);
        verify(!panel.page.securityDirty);
        compare(calls.length, 0);
    }
}
