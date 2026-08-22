import QtQuick
import QtTest
import "../../wifi/NetworkHealth.js" as Health

TestCase {
    name: "NetworkHealth"

    function event(detail) {
        return { stream: "network.health", event: detail.subject, health: detail };
    }

    function test_authenticationFailureIsSurfaced() {
        const failure = event({
            subject: "device", state_name: "failed", unexpected: true, user_requested: false,
            reason: { code: 7, name: "no-secrets", category: "authentication" },
            id: "Example", device_iface: "wlan0"
        });
        verify(Health.isFailure(failure));
        compare(Health.message(failure), "Example needs a password.");
    }

    function test_userRequestedTransitionsStayQuiet() {
        const disconnect = event({
            subject: "connection", state_name: "deactivated", unexpected: false, user_requested: true,
            reason: { code: 2, name: "user-disconnected", category: "user-requested" },
            id: "Example"
        });
        verify(Health.isQuiet(disconnect));
        verify(!Health.isFailure(disconnect));
    }

    function test_unknownReasonsStillReport() {
        const unknown = event({
            subject: "vpn", state_name: "failed", unexpected: true, user_requested: false,
            reason: { code: 9999, name: "unknown", category: "unknown" },
            id: "Work VPN"
        });
        verify(Health.isFailure(unknown));
        compare(Health.message(unknown), "VPN Work VPN is failed.");
    }

    function test_ordinaryProgressIsNotAFailure() {
        const progress = event({
            subject: "device", state_name: "ip-config", unexpected: true, user_requested: false,
            reason: { code: 0, name: "none", category: "none" }, device_iface: "wlan0"
        });
        verify(!Health.isFailure(progress));
    }
}
