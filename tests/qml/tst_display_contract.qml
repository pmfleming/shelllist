pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Displays as Displays

DaemonTestCase {
    id: tests
    name: "DisplayContract"
    when: windowShown
    property var loadedFixture: null
    Component {
        id: factory
        Displays.DisplayController {
            uiActive: true
            property string stateAtRelease: ""
            onActionInFlightChanged: if (!actionInFlight) stateAtRelease = JSON.stringify(displayPolicyState)
        }
    }
    function fixture() {
        if (!loadedFixture) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-displays.json"), false);
            request.send();
            loadedFixture = JSON.parse(request.responseText);
        }
        return loadedFixture;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function requests(controller) {
        return calls.filter(call => call.route.consumerId === controller.backend.sharedConsumerId);
    }
    function effects(controller) { return requests(controller).filter(call => call.method.startsWith("display")); }
    function lastCall(controller, method) {
        const found = requests(controller).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method);
        return found[found.length - 1];
    }
    function reply(call, value) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(value), "", call.route);
    }
    function event(controller, state) {
        const route = Object.assign({}, lastCall(controller, "bar.snapshot").route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(clone(fixture().events[state]), route);
        // Test the fixed fixture deadline against a fixed observation clock, not the wall date.
        controller.clock = fixture().events.preview.data.layout.trial.expires_at * 1000 - 20000;
    }
    function make() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        reply(lastCall(controller, "bar.snapshot"), fixture().snapshots.initial);
        verify(controller.canEdit);
        verify(controller.outputs[0].supported && controller.outputs[0].internal);
        compare(controller.draft[0].mode, "1920x1200@60.00Hz");
        return controller;
    }
    function start(controller, method) {
        const params = fixture().replies[method].params;
        let sent = false;
        switch (method) {
        case "displayLayout.preview":
            controller.edit("eDP-1", "scale", params.outputs[0].scale);
            sent = controller.preview(); break;
        case "displayLayout.confirm": case "displayLayout.revert":
            sent = controller.displayLayoutAction(method.split(".")[1], clone(params)); break;
        case "displayFocus.set": sent = controller.setFocusSetting("input:follow_mouse", params.values["input:follow_mouse"]); break;
        case "displayFocus.reset": sent = controller.resetFocusSettings(); break;
        case "displayPolicy.set": sent = controller.setPreferExternal(params.prefer_external); break;
        }
        verify(sent, method);
        const call = lastCall(controller, method);
        compare(call.params, params, "UI requests must match the producer's typed DTOs");
        verify(controller.actionInFlight);
        verify(controller.backend.isPending(call.route.localId));
        verify(!controller.canChange);
        return call;
    }
    function test_explicitCloseRevertsOnceButLostRevertIsNotReplayed() {
        const controller = make();
        const preview = start(controller, "displayLayout.preview");
        controller.deactivateUi();
        verify(controller.revertOnArrival);
        compare(effects(controller).length, 1, "Wait for authoritative trial identity before requesting safety revert");
        reply(preview, fixture().replies[preview.method].success);
        const revert = lastCall(controller, "displayLayout.revert");
        compare(revert.params, fixture().replies[revert.method].params);
        compare(effects(controller).length, 2);
        verify(!controller.revertOnArrival);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Revert outcome unknown");
        clientReady = true;
        reply(lastCall(controller, "bar.snapshot"), fixture().snapshots.preview);
        wait(0);
        compare(effects(controller).length, 2, "A lost revert reply must not issue another revert");
        event(controller, "reverted");
        compare(controller.trial, null);
        compare(effects(controller).length, 2);
    }
}
