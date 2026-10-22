pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "NotificationDecks"
    width: 500
    height: 650
    visible: true
    when: windowShown
    Component {
        id: factory
        Bar.NotificationToastStack {
            id: deck
            width: 390
            controller: Bar.BarController {
                surfaceRegistry: QtObject {
                    property var notificationState: Activity.NotificationState { id: state }
                    property var wifiController: null
                    property var bluetoothController: null
                }
                backend.active: false
            }
        }
    }
    Component { id: promptFactory; Bar.NotificationSharingPrompt { width: 390 } }
    function test_sharingPromptCapturesSessionAndWaitsForAcknowledgement() {
        const deck = createTemporaryObject(factory, testCase, {group: {key: "chat", records: [record(1)]}});
        deck.visible = false;
        const state = deck.controller.notificationState;
        const summary = {available: true, backend: "native", sharing: {active: true, available: true, prompt: true, generation: 7}};
        state.notifications = summary;
        const prompt = createTemporaryObject(promptFactory, testCase, {controller: deck.controller});
        verify(prompt);
        verify(waitForRendering(prompt));
        const choice = findChild(prompt, "notificationSharingSnooze15");
        mouseClick(choice.button);
        const call = calls.filter(c => c.method === "notifications.snoozeSharing").pop();
        verify(call);
        compare(call.params, {generation: 7, minutes: 15});
        verify(state.sharingPending && state.notifications.sharing.prompt);
        const id = Object.keys(state.backend.requests).find(id => id.startsWith("sharing-"));
        const height = prompt.implicitHeight;
        state.backend.finish(id, {}, "Sharing session changed", "");
        compare(state.sharingError, "Sharing session changed");
        compare(prompt.implicitHeight, height, "Feedback does not grow the prompt");
        verify(!state.sharingPending);
        mouseClick(choice.button);
        const next = Object.keys(state.backend.requests).find(id => id.startsWith("sharing-"));
        state.backend.finish(next, {notifications: Object.assign({}, summary, {sharing: {active: true, prompt: false, generation: 7}})}, "", "");
        compare(state.notifications.sharing.prompt, false);
    }
    function record(id) {
        return {id: id, created_unix_ms: id * 1000, updated_unix_ms: id * 1000,
            summary: "Message " + id, app_name: "Chat", body: "Body", actions: [], hints: {}, toast_visible: true};
    }
    function init() { failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign).*/); calls = []; }
    function test_fanAndDismissWaitsForAcknowledgementAndPreservesDelegates() {
        const deck = createTemporaryObject(factory, testCase, {group: {key: "named:chat", monitor: "test", records: [record(2), record(1)]}});
        verify(deck);
        const state = deck.controller.notificationState;
        state.notifications = {available: true, backend: "native"};
        state.notificationActive = {available: true, notifications: [record(2), record(1)]};
        tryVerify(() => deck.cardHeight > 0);
        const first = findChild(deck, "notificationDeckCard2");
        const second = findChild(deck, "notificationDeckCard1");
        verify(first && second);
        mouseMove(deck, 100, 30);
        tryCompare(deck, "expanded", true);
        tryVerify(() => second.y > first.height);
        const close = findChild(first, "notificationToastDismiss");
        tryCompare(close, "visible", true);
        mouseClick(close);
        tryVerify(() => calls.some(c => c.method === "notifications.dismiss" && c.params.id === 2));
        verify(first.visible, "No optimistic removal before native acknowledgement");
        deck.group = {key: "named:chat", monitor: "test", records: [record(1)]};
        tryCompare(second, "y", 0);
        compare(findChild(deck, "notificationDeckCard1"), second, "Stable record identity retains delegate");
        deck.group = {key: "named:chat", monitor: "test", records: [Object.assign(record(1), {interaction_blocked: true})]};
        const count = calls.length;
        mouseClick(findChild(second, "notificationToastDismiss"));
        mouseClick(findChild(second, "notificationToastSurface"), 100, 30);
        compare(calls.length, count, "A frozen replacement is readable but cannot invoke or dismiss its newer version");
        mouseMove(testCase, 490, 640);
        tryCompare(deck, "expanded", false);
    }
    function test_contextCopyUsesCapturedIdentityAndChecksOnlyAfterAcknowledgement() {
        const n = Object.assign(record(1), {context_actions: [{key: "copy-code", label: "Copy code", icon: "content_copy"}]});
        const deck = createTemporaryObject(factory, testCase, {group: {key: "chat", records: [n]}});
        const state = deck.controller.notificationState;
        state.notifications = {available: true, backend: "native"};
        state.notificationActive = {available: true, notifications: [n]};
        const card = findChild(deck, "notificationDeckCard1");
        const action = findChild(card, "notificationContext-copy-code");
        verify(action);
        tryVerify(() => deck.cardHeight > 0 && action.button.width > 0);
        verify(waitForRendering(deck));
        mouseClick(action.button);
        tryVerify(() => calls.some(c => c.method === "notifications.contextAction"));
        const call = calls.filter(c => c.method === "notifications.contextAction").pop();
        compare(call.params, {id: 1, created_unix_ms: 1000, updated_unix_ms: 1000, key: "copy-code"});
        verify(action.icon !== "check");
        const pending = Object.keys(state.backend.requests).find(id => id.startsWith("context-action-"));
        state.backend.finish(pending, {copied: true}, "", "");
        compare(action.icon, "check");
        const replacement = Object.assign({}, n, {updated_unix_ms: 2000});
        deck.group = {key: "chat", records: [replacement]};
        compare(card.copiedAction, "");
        state.contextActionFinished("1:1000", 1000, "copy-code", true, "");
        compare(card.copiedAction, "", "late copy acknowledgement cannot mark a replacement");
    }
    function test_countdownPreferenceChangesOnlyPresentation() {
        const n = Object.assign(record(1), {created_unix_ms: Date.now(), updated_unix_ms: Date.now(), toast_expires_unix_ms: Date.now() + 30000});
        const deck = createTemporaryObject(factory, testCase, {group: {key: "chat", records: [n]}});
        const state = deck.controller.notificationState;
        state.notifications = {available: true, backend: "native", settings: {countdown: false}};
        const expiry = findChild(deck, "notificationToastCountdown");
        verify(expiry);
        compare(expiry.visible, false);
        state.notifications = {available: true, backend: "native", settings: {countdown: true}};
        compare(expiry.visible, true);
        compare(findChild(deck, "notificationDeckCard1").notification.toast_expires_unix_ms, n.toast_expires_unix_ms);
    }
    function test_nativeProjectionOwnsRoutingAndOrder() {
        const deck = createTemporaryObject(factory, testCase, {group: {key: "chat", records: [record(1)]}});
        deck.controller.notificationActive = {available: true, toast_decks: [{key: "chat", monitor: "DP-1", records: [record(1)]}]};
        compare(deck.controller.visibleToastGroups("DP-1").length, 1);
        compare(deck.controller.visibleToastGroups("DP-2").length, 0);
        deck.controller.workspaces = {focused_monitor: "DP-2"};
        compare(deck.controller.visibleToastGroups("DP-1").length, 1);
    }
}
