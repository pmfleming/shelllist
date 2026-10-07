pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import "../../launcher" as Apps
import "../../launcher/AppApi.js" as Api

DaemonTestCase {
    id: testCase
    name: "ApplicationActions"
    when: windowShown
    visible: true
    width: 1200
    height: 800

    Component {
        id: surfaceComponent
        Apps.ApplicationContent {
            id: surface
            width: testCase.width
            height: testCase.height
            property int dismissals: 0
            property var failures: []
            controller: Apps.ApplicationController {
                onCloseWindowRequested: {
                    surface.dismissals++;
                    deactivateUi();
                }
                onBackgroundActionFailed: function(title, message) {
                    surface.failures = surface.failures.concat([{title: title, message: message}]);
                }
            }
        }
    }
    function application(id, windows) {
        return {id: id, name: id, kind: "desktop-application", revision: 1,
            running: windows.length > 0, focused: false,
            instances: windows.map(w => ({id: w, title: w, workspace_id: "1"})),
            desktop_actions: [], category: "shell"};
    }
    function makePanel() {
        const panel = createTemporaryObject(surfaceComponent, testCase);
        verify(panel !== null);
        const c = panel.controller;
        c.activateUiState("1");
        c.replaceProviderResults([application("Alpha", ["w1", "w2"]), application("Beta", ["w3"])].map(a => c.provider.resultFor(a)), true);
        tryVerify(() => c.hasSelection && panel.listItem !== null);
        c.select(c.filteredResults.findIndex(r => r.id === "Alpha"));
        tryCompare(c.selectedResult, "id", "Alpha");
        panel.listItem.focusList();
        calls = [];
        return panel;
    }
    function lastCall(method) {
        const matches = calls.filter(call => call.method === method);
        verify(matches.length > 0, "Missing " + method);
        return matches[matches.length - 1];
    }
    function reply(call, data, error) {
        Io.DaemonSessions.sessions["app-daemon"].client.response(call.id,
            {protocol: Api.protocol, version: Api.version, ok: !error, data: data}, error || "", call.route);
    }
    function operation(call, status, extra) {
        return Object.assign({id: "op-" + call.id, target_id: call.params.target_id,
            action: call.params.action, status: status, message: status}, extra || {});
    }
    function accept(call) { reply(call, {operation: operation(call, "accepted")}); }
    function event(call, status, extra) {
        Io.DaemonSessions.sessions["app-daemon"].client.eventReceived({protocol: Api.protocol,
            version: Api.version, stream: Api.streams.operation, event: status,
            data: {operation: operation(call, status, extra)}}, null);
    }
    function snapshot(panel, windows, background) {
        panel.controller.refresh(false);
        reply(lastCall(Api.methods.query), {applications: {revision: 2, hyprland_available: true,
            applications: [Object.assign(application("Alpha", windows), {running: !!background || windows.length > 0}), application("Beta", ["w3"])]}});
        wait(0);
    }
    function expand(panel) {
        keyClick(Qt.Key_Right);
        tryCompare(panel.controller, "detailsOpen", true);
        tryVerify(() => findChild(panel, "closeWindow-w1") !== null);
        waitForRendering(panel);
    }
    function test_handoff_data() {
        return [{tag: "focus", launch: false}, {tag: "window-focus", launch: false, window: true}, {tag: "launch-receipt", launch: true}];
    }
    function test_handoff(data) {
        const panel = makePanel();
        if (data.window) {
            expand(panel);
            mouseClick(findChild(panel, "focusWindow-w1"));
        } else {
            keyClick(Qt.Key_Return, data.launch ? Qt.ShiftModifier : Qt.NoModifier);
        }
        const call = lastCall(Api.methods.execute);
        compare(call.params.action, data.window ? "focus-window" : data.launch ? "launch" : "activate");
        accept(call);
        compare(panel.dismissals, 0, "Admission is not a successful handoff");
        verify(!panel.controller.navigationBlocked);
        if (data.launch) {
            event(call, "running", {launch_backend: "systemd-run", launch_scope: "app-graphical.slice"});
            compare(panel.dismissals, 1);
            verify(panel.controller.actionInFlight);
            verify(Io.DaemonSessions.sessions["app-daemon"].client.active, "Hidden operation keeps its subscription");
            event(call, "failed", {message: "Workspace placement failed"});
            compare(panel.failures.length, 1);
            compare(panel.failures[0].message, "Workspace placement failed");
        } else {
            event(call, "completed");
            compare(panel.dismissals, 1);
        }
        verify(!panel.controller.actionInFlight);
        event(call, "completed");
        compare(panel.dismissals, 1, "Duplicate terminal delivery cannot dismiss again");
    }
    function test_placementWarningAfterHandoff_data() {
        return [
            {tag: "unavailable-event", status: "unavailable", statusRead: false},
            {tag: "failed-status-read", status: "failed", statusRead: true},
            {tag: "placed", status: "placed", statusRead: false}
        ];
    }
    function test_placementWarningAfterHandoff(data) {
        const panel = makePanel();
        keyClick(Qt.Key_Return, Qt.ShiftModifier);
        const call = lastCall(Api.methods.execute);
        accept(call);
        event(call, "running", {launch_backend: "uwsm-app", launch_scope: "app-graphical.slice",
            placement: {workspace_id: "3", status: "pending"}});
        compare(panel.dismissals, 1);
        const extra = {launch_backend: "uwsm-app", launch_scope: "app-graphical.slice",
            placement: {workspace_id: "3", status: data.status}, message: "Application started; placement " + data.status};
        // A foreign target cannot retire this launch or report its warning.
        event(call, "completed", Object.assign({}, extra, {target_id: "Beta"}));
        verify(panel.controller.operations.busy("Alpha"));
        compare(panel.failures.length, 0);
        if (data.statusRead) {
            panel.controller.operations.check("Alpha");
            reply(lastCall(Api.methods.operationStatus), {operation_status: operation(call, "completed", extra)});
        } else {
            event(call, "completed", extra);
        }
        compare(panel.failures.length, data.status === "placed" ? 0 : 1);
        if (data.status !== "placed")
            compare(panel.failures[0].message, extra.message);
        compare(panel.controller.operations.feedback.Alpha.placement.status, data.status);
        verify(!panel.controller.operations.busy("Alpha"));
        event(call, "completed", extra);
        compare(panel.failures.length, data.status === "placed" ? 0 : 1, "Duplicate outcomes do not notify twice");
        compare(panel.dismissals, 1);
        compare(calls.filter(c => c.method === Api.methods.execute).length, 1, "Placement recovery never replays launch");
    }
    function test_placementWarningWithoutProgressKeepsVisibleChooserUsable() {
        const panel = makePanel();
        keyClick(Qt.Key_Return, Qt.ShiftModifier);
        const call = lastCall(Api.methods.execute);
        accept(call);
        event(call, "completed", {launch_backend: "uwsm-app", launch_scope: "app-graphical.slice",
            placement: {workspace_id: "3", status: "unavailable"}, message: "Started, but no safely attributable new window"});
        compare(panel.dismissals, 0, "Missed handoff progress must not hide the warning");
        compare(panel.failures.length, 0, "Visible inline feedback needs no background notification");
        compare(panel.controller.selectedActionMessage, "Started, but no safely attributable new window");
        verify(!panel.controller.actionInFlight);
        keyClick(Qt.Key_Down);
        compare(panel.controller.selectedResult.id, "Beta");
        compare(calls.filter(c => c.method === Api.methods.execute).length, 1);
    }
    function test_windowFocusFeedbackUsesAcknowledgedOutcome_data() {
        return [{tag:"completed",status:"completed"}, {tag:"failed",status:"failed"}, {tag:"cancelled",status:"cancelled"}];
    }
    function test_windowFocusFeedbackUsesAcknowledgedOutcome(data) {
        const panel = makePanel();
        expand(panel);
        mouseClick(findChild(panel,"focusWindow-w1"));
        const call = lastCall(Api.methods.execute);
        accept(call);
        verify(!findChild(panel,"windowFocusSuccess-w1").visible,"Admission must not show success");
        verify(findChild(panel,"windowActionStatus-w1").visible,"Progress remains readable");
        // A retained/revisited view can display the result without being dismissed.
        panel.listItem.focusList();
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        const message = data.status === "completed" ? "Fenêtre activée" : "Focus not confirmed; check this window";
        event(call,data.status,{message:message});
        compare(panel.dismissals,0);
        tryVerify(() => findChild(panel,"windowFocusSuccess-w1") !== null);
        const success = findChild(panel,"windowFocusSuccess-w1");
        const status = findChild(panel,"windowActionStatus-w1");
        compare(success.visible,data.status === "completed");
        compare(status.visible,data.status !== "completed");
        compare(status.text,message);
        verify(!findChild(panel,"windowFocusSuccess-w2").visible,"Success is window-scoped");
        verify(!findChild(panel,"windowCurrent-w1").visible,"Operation success cannot invent compositor focus");
        if (data.status === "completed") {
            compare(success.Accessible.name,message);
            mouseClick(success);
            compare(calls.filter(c => c.method === Api.methods.execute).length,1,"Status glyph is passive");
            mouseClick(findChild(panel,"focusWindow-w1"));
            const retry = lastCall(Api.methods.execute);
            verify(!success.visible,"New pending action supersedes old success");
            reply(retry,{},"Could not send application action");
            verify(!success.visible);
            verify(status.visible);
            compare(status.text,"Could not send application action");
        }
    }
    function test_close_reconcilesWindowsAndRestoresCommandFocus() {
        const panel = makePanel();
        const c = panel.controller;
        expand(panel);
        mouseClick(findChild(panel, "windowCommands-w1"));
        tryVerify(() => panel.detailsNavigation.commandMenuOpen);
        keyClick(Qt.Key_Down); // Focus -> Close in the shared per-window menu.
        keyClick(Qt.Key_Return);
        const call = lastCall(Api.methods.execute);
        compare(call.params.window_id, "w1");
        compare(call.params.action, "close-window");
        accept(call);
        event(call, "completed");
        compare(panel.dismissals, 0);
        compare(c.selectedApplication.instances.length, 2, "Dispatch acknowledgement must not remove a window");
        snapshot(panel, ["w1", "w2"]);
        verify(c.selectedActionMessage.indexOf("still open") >= 0);
        verify(findChild(panel, "focusWindow-w1").enabled, "Can reach a save prompt");
        // Put real native focus on the row command before removing that row.
        findChild(panel, "windowCommands-w1").forceActiveFocus();
        snapshot(panel, ["w2"]);
        compare(c.selectedApplication.instances.length, 1);
        verify(panel.detailsNavigation.activeFocus, "Removed command returns to shared browsing");
        compare(c.selectedResult.id, "Alpha");
        keyClick(Qt.Key_C, Qt.AltModifier);
        const all = lastCall(Api.methods.execute);
        compare(all.params.action, "close");
        compare(c.detailActions.find(a => a.id === "close").label, "Close all windows (1)");
        accept(all);
        event(all, "completed");
        snapshot(panel, [], true);
        verify(c.selectedApplication.running, "Background processes may survive closing all windows");
        compare(c.detailActions.find(a => a.id === "activate").label, "Launch");
        verify(findChild(panel, "applicationEmptyState").text.indexOf("No open windows") === 0);
        verify(!c.detailActions.find(a => a.id === "close").enabled);
        verify(c.selectedActionMessage.indexOf("windows closed") >= 0);
        compare(panel.dismissals, 0);
        keyClick(Qt.Key_A, Qt.AltModifier);
        compare(lastCall(Api.methods.execute).params.action, "activate", "Launch remains reachable after the last close");
    }
    function test_pendingActionDoesNotLockBrowsingOrOtherTargets() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.triggerDetailAction("close"));
        const first = lastCall(Api.methods.execute);
        accept(first);
        verify(!c.triggerDetailAction("close"), "Duplicate/conflicting action stays guarded");
        const view = findChild(panel, "resultListView");
        tryVerify(() => view.itemAtIndex(1) !== null);
        verify(findChild(view.itemAtIndex(1), "applicationFocus-Beta").enabled, "Other apps' pointer commands remain usable");
        verify(!findChild(view.itemAtIndex(0), "applicationClose-Alpha").enabled);
        keyClick(Qt.Key_Down);
        compare(c.selectedResult.id, "Beta");
        keyClick(Qt.Key_Right);
        tryCompare(c, "detailsOpen", true);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        compare(c.detailsTab, "resources");
        keyClick(Qt.Key_F5);
        lastCall(Api.methods.refresh);
        keyClick(Qt.Key_Return);
        const second = lastCall(Api.methods.execute);
        compare(second.params.target_id, "Beta");
        accept(second);
        event(first, "completed");
        verify(c.operations.busy("Beta"));
        compare(panel.dismissals, 0);
        // Old request errors cannot retire a newer/other operation.
        reply(first, {}, "late obsolete error");
        verify(c.operations.busy("Beta"));
        event(second, "completed");
        compare(panel.dismissals, 1);
    }
    function test_reopenedPanelIsNotDismissedByOldOperation() {
        const panel = makePanel();
        keyClick(Qt.Key_Return);
        const call = lastCall(Api.methods.execute);
        accept(call);
        keyClick(Qt.Key_Escape);
        compare(panel.dismissals, 1);
        verify(panel.controller.actionInFlight);
        panel.controller.activateUiState("1");
        event(call, "completed");
        compare(panel.dismissals, 1);
        verify(panel.controller.uiActive);
        verify(!panel.controller.actionInFlight);
    }
    function test_navigationAndRejectionDoNotStealFocus() {
        const panel = makePanel();
        const c = panel.controller;
        keyClick(Qt.Key_Return);
        const call = lastCall(Api.methods.execute);
        accept(call);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Up);
        compare(c.selectedResult.id, "Alpha");
        event(call, "completed");
        compare(panel.dismissals, 0, "Navigating away and back retires the original handoff view");
        keyClick(Qt.Key_Return);
        const rejected = lastCall(Api.methods.execute);
        reply(rejected, {}, "Compositor rejected focus");
        compare(panel.dismissals, 0);
        verify(!c.actionInFlight);
        compare(c.selectedActionMessage, "Compositor rejected focus");
        verify(panel.listItem.listFocused);
    }
    function test_statusRecoveryIsOwnedReadOnlyAndDoesNotReplay() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.triggerDetailAction("close"));
        const call = lastCall(Api.methods.execute);
        // An early event is not trusted without the admission/owned read.
        event(call, "completed");
        verify(c.actionInFlight);
        accept(call);
        expand(panel);
        keyClick(Qt.Key_K, Qt.AltModifier);
        const check = lastCall(Api.methods.operationStatus);
        compare(check.params.operation_id, operation(call, "accepted").id);
        reply(check, {operation_status: operation(call, "completed", {target_id: "foreign"})});
        verify(c.actionInFlight);
        c.operations.check("Alpha");
        reply(lastCall(Api.methods.operationStatus), {operation_status: operation(call, "completed")});
        verify(!c.actionInFlight);
        compare(c.selectedApplication.instances.length, 2);
        compare(calls.filter(call => call.method === Api.methods.execute).length, 1);
    }
    function test_malformedStatusRetiresOnlyItsReadAndAllowsRecovery() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.triggerDetailAction("close"));
        const call = lastCall(Api.methods.execute);
        accept(call);
        const original = JSON.stringify(c.operations.pending);
        c.applyOperation("", null);
        verify(!c.operations.finishStatus("", null, "Unowned error"));
        compare(JSON.stringify(c.operations.pending), original);
        let previous = null;
        for (const data of [{}, {operation_status: null}, {operation_status: {}}]) {
            c.operations.check("Alpha");
            const read = lastCall(Api.methods.operationStatus);
            if (previous) {
                verify(read.id !== previous.id);
                const requestId = c.operations.forTarget("Alpha").statusRequestId;
                reply(previous, {}, "Obsolete read failure");
                compare(c.operations.forTarget("Alpha").statusRequestId, requestId);
            }
            reply(read, data);
            compare(c.operations.forTarget("Alpha").statusRequestId, "");
            verify(c.operations.busy("Alpha"), "An empty status is not mutation completion");
            compare(panel.dismissals, 0);
            previous = read;
        }
        c.operations.check("Alpha");
        reply(lastCall(Api.methods.operationStatus), {operation_status: operation(call, "completed")});
        verify(!c.operations.busy("Alpha"));
        compare(calls.filter(call => call.method === Api.methods.execute).length, 1);
    }
    function test_feedbackIsBoundedAndEvictionCannotRetirePendingOperations() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.triggerDetailAction("close"));
        const call = lastCall(Api.methods.execute);
        accept(call);
        const owned = c.operations.forTarget("Alpha");
        const publish = (id, message) => c.operations.publish(Object.assign({}, owned, {
            request: Object.assign({}, owned.request, {result: {id: id, title: id}}), message: message
        }));
        for (let index = 0; index < 65; ++index)
            publish("cached-" + index, "Old feedback");
        compare(Object.keys(c.operations.feedback).length, 64);
        compare(c.operations.feedback["cached-0"], undefined);
        compare(c.operations.feedback.Alpha, undefined);
        publish("cached-1", "Updated feedback");
        publish("__proto__", "Opaque target ID");
        compare(Object.keys(c.operations.feedback).length, 64);
        compare(c.operations.feedback["cached-2"], undefined, "Updating a target moves it to the newest end");
        compare(c.operations.message("cached-1", ""), "Updated feedback");
        c.operations.reconcile([]);
        verify(Object.prototype.hasOwnProperty.call(c.operations.feedback, "__proto__"), "Reconciliation preserves opaque keys too");
        compare(c.operations.message("__proto__", ""), "Opaque target ID");
        compare(c.operations.forTarget("Alpha").request.id, owned.request.id);
        compare(c.operations.message("Alpha", ""), owned.message, "Pending ownership takes precedence over the feedback cache");
        compare(calls.filter(call => call.method === Api.methods.execute).length, 1);
    }
    function test_readFailureAndTransportLossStayExplicit() {
        const panel = makePanel();
        const c = panel.controller;
        verify(c.primarySelected());
        const call = lastCall(Api.methods.execute);
        accept(call);
        c.operations.check("Alpha");
        reply(lastCall(Api.methods.operationStatus), {}, "Status unavailable");
        verify(c.actionInFlight, "A failed read does not complete the mutation");
        verify(c.selectedActionMessage.indexOf("Could not confirm") >= 0);
        verify(!c.navigationBlocked);
        c.deactivateUi();
        Io.DaemonSessions.sessions["app-daemon"].client.transportFailed("Disconnected");
        verify(!c.actionInFlight);
        compare(panel.failures.length, 1);
        verify(panel.failures[0].message.indexOf("outcome unknown") >= 0);
        compare(calls.filter(call => call.method === Api.methods.execute).length, 1);
    }
}
