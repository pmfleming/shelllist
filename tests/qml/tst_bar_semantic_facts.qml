pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import "../../qml/Shelllist/Bar/BarStatusPresentation.js" as Status
import "../../qml/Shelllist/Bar/BarOsdPresentation.js" as Osd

DaemonTestCase {
    id: tests
    name: "BarSemanticFacts"
    when: windowShown
    Component { id: factory; Bar.BarController { surfaceRegistry: null } }

    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function fixture() {
        const request = new XMLHttpRequest();
        request.open("GET", Qt.resolvedUrl("fixtures/bar-reads.json"), false);
        request.send();
        return JSON.parse(request.responseText);
    }
    function make() {
        const controller = createTemporaryObject(factory, tests);
        const read = calls.find(call => call.method === "bar.snapshot");
        const envelope = fixture().snapshot;
        Io.DaemonSessions.sessions["bar-daemon"].client.response(read.id, envelope, "", read.route);
        return controller;
    }
    function powerEvent(profile: var, revision: int): void {
        const event = fixture().changed["power-profile.changed"];
        event.data = Object.assign(event.data, profile);
        event.data._publication.revision = revision;
        const read = calls.find(call => call.method === "bar.snapshot");
        emitBaseEvent("bar-daemon", Object.assign({}, read.route,
            {kind: "base-subscription", localId: "session-subscribe"}), event);
    }
    function sets() { return calls.filter(call => call.method === "powerProfile.set"); }

    function test_nativeUnitsAndExplicitChargeState() {
        const controller = make();
        const native = controller.battery;
        verify(Status.batteryTooltip(native).includes(native.display.power));
        verify(Status.batteryTooltip(native).includes(native.display.health));
        verify(Status.batteryTooltip(native).includes(native.display.cycles));
        const gaugeComponent = Qt.createComponent(Qt.resolvedUrl("../../qml/Shelllist/Bar/BarBatteryGauge.qml"));
        compare(gaugeComponent.status, Component.Ready, gaugeComponent.errorString());
        const gauge = createTemporaryObject(gaugeComponent, tests, {battery: native});
        verify(gauge.known);
        verify(!controller.osdVisible, "A native baseline does not replay an OSD edge");
        const zero = Object.assign({}, native, {percentage: 0});
        gauge.battery = zero;
        verify(gauge.known);
        compare(gauge.fraction, 0, "An observed zero is still known");
        for (const state of ["charge-paused", "charging-inhibited", "fully-charged"]) {
            const value = Object.assign({}, native, {percentage: 100, plugged: true, charging: false, state: state});
            gauge.battery = value;
            compare(gauge.stateMark, state === "fully-charged" ? "check" : "power");
            compare(Status.batteryTooltip(value).includes("Fully charged"), state === "fully-charged");
        }
        gauge.battery = Object.assign({}, native, {available: false});
        verify(!gauge.known);
        compare(gauge.stateMark, "help_outline");
        compare(Status.batteryTooltip(gauge.battery), "Battery reading unavailable");
        const missing = Object.assign({}, native, {display: undefined, power_watts: 0});
        verify(Status.batteryTooltip(missing).includes("— W"));
        verify(!Status.batteryTooltip(missing).includes("0.0 W"));
        compare(sets().length, 0);
    }
    function test_unknownOsdReadingsAreNotZero() {
        const controller = make();
        for (const value of [undefined, null, NaN, Infinity, -1, 101, "0"]) {
            controller.showOutputOsd({available: true, volume_percent: value});
            compare(controller.osd.valueLabel, "Unavailable");
            verify(!controller.osd.progressVisible);
            controller.showBrightnessOsd({available: true, percent: value});
            compare(controller.osd.valueLabel, "Unavailable");
            verify(!controller.osd.progressVisible);
            const keyboard = Osd.keyboardBacklightOsd(value);
            compare(keyboard.valueLabel, "Unavailable");
            verify(!keyboard.progressVisible);
        }
        for (const available of [false, undefined]) {
            compare(Osd.outputOsd({available: available, volume_percent: 0}).valueLabel, "Unavailable");
            compare(Osd.brightnessOsd({available: available, percent: 0}).valueLabel, "Unavailable");
        }
        for (const value of [0, 100]) {
            controller.showOutputOsd({available: true, volume_percent: value});
            compare(controller.osd.valueLabel, value + "%");
            verify(controller.osd.progressVisible);
            controller.showBrightnessOsd({available: true, percent: value});
            compare(controller.osd.valueLabel, value + "%");
            verify(controller.osd.progressVisible);
            compare(Osd.keyboardBacklightOsd(value).valueLabel, value + "%");
        }
        compare(sets().length, 0);
    }
    function test_explicitCycleCapturesOneNativeTargetAndNeverRetries() {
        const controller = make();
        verify(!controller.cyclePowerProfile(), "Single native profile has no eligible target");
        for (const target of [undefined, null, "", "extension"]) {
            controller.powerProfile = {available: true, profile: "balanced", profiles: [{name: "balanced"}, {name: "performance"}], next_manual_profile: target};
            verify(!controller.cyclePowerProfile());
        }
        controller.powerProfile = {available: false, next_manual_profile: "performance"};
        verify(!controller.cyclePowerProfile(), "Unavailable state cannot authorize a projected command");
        compare(sets().length, 0);
        powerEvent({available: true, profile: "balanced", next_manual_profile: "performance"}, 10);
        verify(controller.triggerModuleAction("power-profile-next"));
        compare(sets().length, 1);
        compare(sets()[0].params, {profile: "performance"});
        verify(!controller.cyclePowerProfile(), "Pending command blocks duplicate dispatch");
        controller.triggerModuleAction("power-profile-next");
        compare(sets().length, 1, "The actual bar route also respects the pending guard");
        powerEvent({profile: "power-saver", next_manual_profile: "balanced"}, 11);
        compare(sets()[0].params, {profile: "performance"}, "Observation cannot retarget the captured request");
        const submitted = sets()[0];
        Io.DaemonSessions.sessions["bar-daemon"].client.response(submitted.id,
            {protocol: "bar-api", version: 2, ok: false, error: {code: "failed", message: "Target removed"}}, "", submitted.route);
        wait(0);
        compare(sets().length, 1, "Failure never retries or cycles automatically");
        verify(controller.backend.operationError.includes("Target removed"));
        powerEvent({profile: "balanced", next_manual_profile: "performance"}, 10);
        compare(controller.powerProfile.next_manual_profile, "balanced", "Stale projection cannot restore an older target");
        verify(controller.triggerModuleAction("power-profile-next"), "Only explicit retry submits the current native target");
        compare(sets().length, 2);
        compare(sets()[1].params, {profile: "balanced"});
    }
}
