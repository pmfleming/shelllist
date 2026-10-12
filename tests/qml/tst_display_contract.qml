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
    function prepare(controller, method) {
        if (["displayLayout.confirm", "displayLayout.revert"].includes(method))
            event(controller, "preview");
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
    function test_replyOutcomes_data() {
        const rows = [];
        for (const method of Object.keys(fixture().replies))
            for (const outcome of ["success", "failed", "rejected", "uncertain"])
                rows.push({tag: method + "/" + outcome, method: method, outcome: outcome});
        return rows;
    }
    function test_replyOutcomes(data) {
        const controller = make();
        prepare(controller, data.method);
        const before = JSON.stringify(controller.displayPolicyState);
        const call = start(controller, data.method);
        compare(JSON.stringify(controller.displayPolicyState), before, "Sending is not acknowledgement");
        const response = fixture().replies[data.method][data.outcome];
        reply(call, response);
        verify(!controller.actionInFlight);
        verify(!controller.backend.isPending(call.route.localId));
        compare(controller.pendingAction, "");
        if (response.ok) {
            compare(controller.displayPolicyState, response.data.display_policy);
            compare(controller.stateAtRelease, JSON.stringify(controller.displayPolicyState), "Authoritative state must be applied before releasing mutation guards");
            compare(controller.displayPolicyError, "");
            if (data.method === "displayLayout.preview") {
                compare(controller.trial.id, response.data.display_policy.layout.trial.id);
                verify(!controller.canEdit && !controller.canSetPolicy && !controller.canSetFocus);
            } else if (["displayLayout.confirm", "displayLayout.revert"].includes(data.method)) {
                compare(controller.trial, null);
                verify(!controller.dirty);
                compare(controller.draft[0].scale, response.data.display_policy.outputs[0].scale);
            } else if (data.method === "displayPolicy.set") {
                verify(controller.dockingApplying, "Acknowledging a preference does not prove the compositor applied it");
                verify(!controller.canEdit);
                event(controller, "settled");
                verify(!controller.dockingApplying && controller.canEdit);
            }
        } else {
            compare(JSON.stringify(controller.displayPolicyState), before);
            compare(controller.displayPolicyError, response.error.message);
        }
        compare(effects(controller).length, 1, "Failures and uncertain replies cannot replay effects");
    }
    function test_reconnectReadsWithoutReplaying_data() {
        return Object.keys(fixture().replies).map(method => ({tag: method, method: method}));
    }
    function test_reconnectReadsWithoutReplaying(data) {
        const controller = make();
        prepare(controller, data.method);
        const call = start(controller, data.method);
        clientReady = false;
        Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Display outcome unknown");
        verify(!controller.actionInFlight && !controller.stateReady);
        verify(!controller.backend.isPending(call.route.localId));
        compare(controller.displayPolicyError, "Display outcome unknown");
        const reads = requests(controller).filter(call => call.method === "bar.snapshot").length;
        clientReady = true;
        compare(requests(controller).filter(call => call.method === "bar.snapshot").length, reads + 1);
        const state = fixture().replies[data.method].recovery;
        reply(lastCall(controller, "bar.snapshot"), fixture().snapshots[state]);
        compare(controller.displayPolicyState, fixture().snapshots[state].data.snapshot.display_policy);
        verify(controller.stateReady && !controller.actionInFlight);
        wait(0);
        compare(effects(controller).length, 1, "Recovery observes the result; it cannot reapply or confirm an uncertain change");
    }
    function test_daemonRollbackAndExpiryAreAuthoritative() {
        const controller = make();
        const call = start(controller, "displayLayout.preview");
        reply(call, fixture().replies[call.method].success);
        const id = controller.trial.id;
        verify(!controller.displayLayoutAction("confirm", {id: "wrong-token"}));
        event(controller, "expired");
        compare(controller.secondsLeft, 0);
        verify(!controller.displayLayoutAction("confirm", {id: id}));
        compare(effects(controller).length, 1, "The UI does not race the daemon's timeout rollback");
        event(controller, "reverted");
        compare(controller.trial, null);
        verify(!controller.dirty && controller.canEdit);
        compare(controller.draft[0].scale, fixture().events.reverted.data.outputs[0].scale);
        compare(effects(controller).length, 1);
    }
    function test_failedRollbackRetainsTrialAndError() {
        const controller = make();
        event(controller, "preview");
        event(controller, "rollback-failed");
        compare(controller.trial.id, fixture().events.preview.data.layout.trial.id);
        verify(controller.dockingFailed);
        verify(controller.statusMessage.includes("Layout rollback failed"));
        verify(!controller.canEdit && !controller.canSetPolicy);
        compare(effects(controller).length, 0);
    }
    function test_externalChangeMakesLocalDraftStaleWithoutApplyingIt() {
        const controller = make();
        controller.edit("eDP-1", "scale", 2);
        const draft = JSON.stringify(controller.draft);
        event(controller, "stale");
        verify(controller.stale && !controller.canPreview);
        compare(JSON.stringify(controller.draft), draft);
        verify(!controller.preview());
        compare(effects(controller).length, 0);
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
