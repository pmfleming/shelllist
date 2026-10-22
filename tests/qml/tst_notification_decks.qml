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
        mouseMove(testCase, 490, 640);
        tryCompare(deck, "expanded", false);
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
