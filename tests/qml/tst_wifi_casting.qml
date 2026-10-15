pragma ComponentBehavior: Bound

import QtQuick
import "../../wifi" as Wifi

DaemonTestCase {
    id: testCase
    name: "WifiCasting"
    when: windowShown
    visible: true
    width: 720
    height: 760

    function init() {
        calls = [];
    }

    Component {
        id: panelComponent
        Item {
            id: panel
            width: testCase.width
            height: testCase.height
            property alias controller: controller
            property alias page: page
            Wifi.WifiPromptController {
                id: prompt
            }
            Wifi.WifiController {
                id: controller
                prompt: prompt
            }
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
            version: "saved-version",
            casting_enabled: enabled,
            mac_address_policy: "stable",
            send_hostname: false,
            autoconnect: true,
            metered: "auto",
            hidden: false,
            security_type: "WPA2 Personal",
            ipv4: {
                method: "auto"
            },
            ipv6: {
                method: "auto"
            }
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

    function test_sharingIsExplicitAndLateRepliesCannotRestoreSecrets() {
        const panel = makePanel(false);
        const controller = panel.controller;
        controller.replaceProviderResults([
            {
                id: "wifi:test",
                provider: "wifi",
                title: "Test",
                payload: {
                    key: "test",
                    ssid: "Test",
                    share: {
                        requires_profile_secret_check: true,
                        profile_path: profile(false).path
                    }
                }
            }
        ], true);
        controller.shareController.refresh();
        verify(controller.shareController.available);
        compare(calls.length, 0, "availability must never request a password");
        controller.shareSelected();
        compare(calls.length, 1);
        compare(calls[0].params.operation, "share");
        const response = {
            protocol: "nm-api",
            version: 2,
            ok: true,
            data: {
                result: {
                    path: profile(false).path,
                    shareable: true,
                    qr_payload: "secret-payload",
                    password: "secret-password",
                    qr_svg: "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
                }
            }
        };
        controller.shareController.applyResponse(response, "");
        compare(controller.qr.password, "secret-password");
        verify(controller.qr.imageSource.indexOf("data:image/svg+xml;") === 0);
        controller.qr.close();
        controller.shareController.applyResponse(response, "");
        compare(controller.qr.password, "");
        compare(controller.qr.payload, "");
        compare(controller.qr.imageSource, "");
        controller.qr.begin("Another network");
        controller.shareController.applyResponse(response, "");
        compare(controller.qr.password, "", "an old generation cannot fill a reopened dialog");
    }

    function test_partialSaveReloadsVersionButKeepsLiveFailureVisible() {
        const panel = makePanel(false);
        panel.page.setCastingEnabled(true);
        panel.page.saveDirty();
        panel.controller.backend.acceptSharedResponse("advanced-save", {
            error: {
                details: {
                    profile_saved: true,
                    live_applied: false
                }
            }
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

}
