pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Bar as Bar
import Shelllist.Battery as Battery

DaemonTestCase {
    id: tests
    name: "BarControlContract"
    when: windowShown
    property var fixtures: ({})
    Component { id: barFactory; Bar.BarController { surfaceRegistry: null } }
    Component { id: batteryFactory; Battery.BatteryController { uiActive: true } }

    function fixture(file) {
        if (!fixtures[file]) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/" + file), false);
            request.send();
            fixtures[file] = JSON.parse(request.responseText);
        }
        return fixtures[file];
    }
    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function requests(controller) {
        return calls.filter(call => call.route.consumerId === controller.backend.sharedConsumerId);
    }
    function effects(controller) {
        return requests(controller).filter(call => !["bar.snapshot", "battery.history"].includes(call.method));
    }
    function lastCall(controller, method) {
        const matching = requests(controller).filter(call => call.method === method);
        verify(matching.length > 0, "Missing " + method);
        return matching[matching.length - 1];
    }
    function reply(call, value) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, value, "", call.route);
    }
    function make(battery) {
        const controller = createTemporaryObject(battery ? batteryFactory : barFactory, tests);
        verify(controller !== null);
        reply(lastCall(controller, "bar.snapshot"), fixture("bar-reads.json").snapshot);
        if (battery) {
            // Establish a selectable, paused baseline without manufacturing wire envelopes.
            const profile = fixture("bar-controls.json")["powerProfile.set"].success.data.power_profile;
            controller.applyPowerProfile(Object.assign({}, profile, {
                profile: "balanced", battery_aware: false,
                battery_automation: Object.assign({}, profile.battery_automation, {status: "paused"})
            }));
        }
        return controller;
    }
    function cases(battery) {
        // Sample distinct state/error owners; generated schemas cover all nine DTOs.
        const rows = battery
            ? [["powerProfile.set", "limited"], ["powerProfile.setBatteryAware", "rejected"]]
            : [["audio.setInputMuted", "success"],
                ["audio.adjust", "limited"], ["brightness.adjust", "limited"],
                ["brightness.adjust", "failed"], ["audio.setInputMuted", "rejected"]];
        return rows
            .map(([method, outcome]) => ({tag: method + "/" + outcome, method: method, outcome: outcome, battery: battery}));
    }
    function start(controller, method, battery) {
        const params = fixture("bar-controls.json")[method].params;
        let sent = false;
        switch (method) {
        case "audio.adjust": sent = controller.adjustAudio(params.delta_percent); break;
        case "audio.setMuted": sent = controller.toggleMuted(); break;
        case "audio.setInputMuted": sent = controller.toggleInputMuted(); break;
        case "brightness.adjust": sent = controller.adjustBrightness(params.delta_percent); break;
        case "powerProfile.set": sent = battery ? controller.setPowerProfile(params.profile) : controller.backend.setPowerProfile(params.profile); break;
        case "powerProfile.resumeAutomatic": sent = controller.resumeAutomaticProfiles(); break;
        case "powerProfile.setBatteryAware": sent = controller.setBatteryAware(params.enabled); break;
        case "powerProfile.setActionEnabled": sent = controller.setPowerActionEnabled(params.action, params.enabled); break;
        }
        verify(sent, method);
        const call = lastCall(controller, method);
        compare(call.params, params, "Frontend requests must match the daemon's typed request examples");
        verify(controller.backend.isPending(call.route.localId));
        return call;
    }
    function propertyFor(method) {
        return method.startsWith("audio.") ? "audio" : method.startsWith("brightness.") ? "brightness" : "powerProfile";
    }
    function fieldFor(method) {
        return method.startsWith("powerProfile.") ? "power_profile" : propertyFor(method);
    }
    function checkOutcome(data) {
        const controller = make(data.battery);
        const property = propertyFor(data.method);
        const before = JSON.stringify(controller[property]);
        const call = start(controller, data.method, data.battery);
        compare(JSON.stringify(controller[property]), before, "Sending is not acknowledgement");
        const response = fixture("bar-controls.json")[data.method][data.outcome];
        reply(call, response);
        verify(!controller.backend.isPending(call.route.localId));
        if (data.battery)
            verify(!controller.actionInFlight);
        if (response.ok) {
            compare(controller[property], response.data[fieldFor(data.method)]);
            compare(data.battery ? controller.lastError : controller.backend.operationError, "");
            if (!data.battery && ["audio.adjust", "audio.setMuted", "audio.setInputMuted", "brightness.adjust"].includes(data.method)) {
                verify(controller.osdVisible);
                compare(controller.osd.kind, data.method === "audio.setInputMuted" ? "input" : property);
                if (data.method === "brightness.adjust")
                    compare(controller.osd.percent, response.data.brightness.percent, "Show actual readback, not the requested delta");
                else if (data.method !== "audio.setInputMuted")
                    compare(controller.osd.percent, response.data.audio.volume_percent);
            }
            if (data.outcome === "limited" && property === "powerProfile") {
                compare(controller.powerProfile.performance_degraded, "high-operating-temperature");
                compare(controller.powerProfile.battery_aware, null, "Unknown optional telemetry must stay unknown");
            }
        } else {
            compare(JSON.stringify(controller[property]), before, "Rejection cannot replace acknowledged state");
            compare(data.battery ? controller.lastError : controller.backend.operationError, response.error.message);
            if (data.method === "brightness.adjust") {
                compare(controller.osd.kind, "brightness-error");
                verify(!controller.osd.progressVisible);
            } else if (!data.battery) {
                verify(!controller.osdVisible, "Failed controls must not show a success OSD");
            }
        }
        compare(effects(controller).length, 1, "Neither limitations nor errors may replay effects");
    }
    function test_barOutcomes_data() { return cases(false); }
    function test_barOutcomes(data) { checkOutcome(data); }
    function test_batteryOutcomes_data() { return cases(true); }
    function test_batteryOutcomes(data) { checkOutcome(data); }
    function test_recoveryNeverReplays_data() {
        return [["brightness.adjust", false], ["powerProfile.set", true]]
            .map(([method, battery]) => ({tag: (battery ? "battery/" : "bar/") + method, method: method, battery: battery}));
    }
    function test_recoveryNeverReplays(data) {
        const controller = make(data.battery);
        const call = start(controller, data.method, data.battery);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Control outcome unknown");
        verify(!controller.backend.isPending(call.route.localId));
        if (data.battery) {
            verify(!controller.actionInFlight);
            compare(controller.lastError, "Control outcome unknown");
        } else {
            compare(controller.backend.operationError, "Control outcome unknown");
        }
        clientReady = true;
        reply(lastCall(controller, "bar.snapshot"), fixture("bar-reads.json").snapshot);
        wait(0);
        compare(effects(controller).length, 1, "Reconnect may read current state, never repeat an adjustment or toggle");
    }
}
