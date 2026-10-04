import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "Notifications"
    width: 1100
    height: 650
    visible: true
    when: windowShown

    Component {
        id: stateComponent
        Activity.NotificationState {}
    }
    Component {
        id: controllerComponent
        Activity.NotificationController {}
    }
    Component {
        id: contentComponent
        Activity.NotificationContent {}
    }
    Component {
        id: fakeBackendComponent
        Activity.NotificationBackend {
            property var requestedCursor: null
            property bool requestedRefresh: false
            property bool requestedDnd: false
            property var requestedUntil: null
            property int dndCalls: 0
            function setDnd(enabled: bool, until: var): bool {
                requestedDnd = enabled;
                requestedUntil = until;
                dndCalls++;
                return true;
            }
            active: false
            function loadHistory(cursor: var, refresh: bool): bool {
                requestedCursor = cursor;
                requestedRefresh = refresh;
                return true;
            }
            function reply(id: int, text: string): bool {
                return true;
            }
        }
    }

    function init() {
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function notification(id, app) {
        return {
            id: id,
            app_name: app || "Chat",
            group_key: app || "chat",
            summary: "Message " + id,
            body: "Body " + id,
            created_unix_ms: id * 1000,
            actions: [
                {
                    key: "reply",
                    label: "Reply"
                },
                {
                    key: "open",
                    label: "Open"
                }
            ]
        };
    }
    function record(id, app) {
        return {
            history_id: id,
            notification: notification(id, app)
        };
    }
    function makeState() {
        const state = createTemporaryObject(stateComponent, testCase);
        verify(state !== null);
        state.notifications = {
            available: true,
            count: 2,
            dnd: false
        };
        state.notificationActive = {
            notifications: [notification(1), notification(100)]
        };
        state.history = [record(3), record(2), record(1)];
        return state;
    }
    function makeController(state) {
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state,
            width: testCase.width,
            height: testCase.height
        });
        verify(controller !== null);
        controller.rebuildRecords();
        return controller;
    }
    function test_unifiedListUsesIndividualStableRecords() {
        const state = makeState();
        const controller = makeController(state);
        compare(controller.notificationModel.count, 4, "live/history overlap is not duplicated");
        compare(controller.selectedRecord.id, 100);
        controller.select(2);
        const key = controller.selectedKey;
        state.notificationActive = {notifications: [notification(101), notification(100), notification(1)]};
        compare(controller.selectedKey, key);
        compare(controller.selectionModel.selectedIndex, 3);
        controller.filterText = "Message 2";
        compare(controller.notificationModel.count, 1);
        compare(controller.selectedRecord.notification.id, 2);
        controller.openNotifications("chat", "history", "activity");
        compare(controller.selectedRecord.id, 101);
        verify(controller.detailsOpen);
        compare(controller.returnSurface, "activity");
        state.history = state.history.concat([record(101)]);
        compare(controller.notificationModel.count, 5);
        state.notificationActive = {notifications: [notification(100), notification(1)]};
        compare(controller.selectedRecord.history_id, 101);
        compare(controller.selectedKey, "101:101000", "closing retains identity and selection");
    }
    function test_dndToggleAndDurationCycle() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {
            store: state
        });
        compare(state.dndDurationMinutes, 30);
        state.cycleDndDuration();
        compare(state.dndDurationMinutes, 60);
        compare(state.backend.dndCalls, 0);
        const now = Date.now();
        verify(state.setDndEnabled(true));
        verify(state.backend.requestedDnd);
        verify(state.backend.requestedUntil >= now + 3600000);
        verify(!state.notifications.dnd, "daemon owns acknowledged DND state");
        state.notifications = {
            available: true,
            dnd: true
        };
        state.cycleDndDuration();
        compare(state.dndDurationMinutes, 0);
        verify(state.backend.requestedDnd);
        compare(state.backend.requestedUntil, null);
        state.cycleDndDuration();
        compare(state.dndDurationMinutes, 30);
        verify(state.backend.requestedUntil >= now + 1800000);
        state.setDndEnabled(false);
        verify(!state.backend.requestedDnd);
        compare(state.backend.requestedUntil, null);
        compare(state.dndDurationMinutes, 30);
    }
    function test_refreshCatchesUpAcrossMissingPages() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {
            store: state
        });
        const page = [];
        for (let id = 100; id > 50; --id)
            page.push(record(id));
        state.historyLoading = true;
        state.applyHistory(page, true);
        compare(state.backend.requestedCursor, 51);
        verify(state.backend.requestedRefresh);
        verify(state.historyLoading);
        const rest = [];
        for (let id = 50; id >= 3; --id)
            rest.push(record(id));
        state.applyHistory(rest, true);
        compare(state.history.length, 100);
        verify(!state.historyLoading);
    }
    function test_replyAcknowledgementAndFailure() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {
            store: state
        });
        state.setDraft(100, "Hello");
        verify(state.replyNotification(100, "Hello"));
        compare(state.drafts[100], "Hello");
        verify(state.replies[100].pending);
        verify(!state.replyNotification(100, "Hello"));
        state.finishReply(100, "Hello", "Connection lost");
        compare(state.drafts[100], "Hello");
        verify(!state.replies[100].pending);
        compare(state.replies[100].error, "Connection lost");
        verify(state.replyNotification(100, "Hello"));
        state.finishReply(100, "Hello", "");
        compare(state.drafts[100], undefined);
        state.setDraft(100, "Newer draft");
        state.finishReply(100, "Older draft", "");
        compare(state.drafts[100], "Newer draft");
    }
    function test_liveUpdateRetainsReplyDelegateAndFocus() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        controller.openDetails();
        state.setDraft(100, "Draft");
        const content = createTemporaryObject(contentComponent, controller, {
            controller: controller,
            width: 453,
            height: 600
        });
        verify(content !== null);
        wait(50);
        const row = findChild(content, "notificationHistoryRow-100");
        verify(row !== null);
        const field = findChild(row, "notificationReplyInput");
        verify(field !== null);
        field.focusInput(false);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_T);
        compare(state.drafts[100], "Draft", "reply typing is local until save");
        state.notificationActive = {
            notifications: [notification(101), notification(100), notification(1)]
        };
        wait(50);
        compare(findChild(content, "notificationHistoryRow-100"), row);
        verify(field.inputActiveFocus);
        compare(field.text, "Draftt");
        // More than the generic model's reorder/chunk thresholds: live reply
        // editors still move with their stable identity, never a reset.
        const burst = Array.from({
            length: 205
        }, (_, index) => notification(index + 1000));
        state.notificationActive = {
            notifications: burst.concat([notification(100), notification(1)])
        };
        wait(50);
        compare(findChild(content, "notificationHistoryRow-100"), row);
        verify(field.inputActiveFocus);
        compare(field.text, "Draftt");
        keyClick(Qt.Key_Return);
        compare(state.drafts[100], "Draftt");
        content.destroy();
        wait(50);
    }
    function test_quickActionsUseCommandMenuNotFieldTraversal() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        controller.openDetails();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 900, height: 600});
        tryVerify(() => findChild(content, "notificationHistoryRow-100") !== null);
        mouseMove(testCase, 1090, 640);
        const row = findChild(content, "notificationHistoryRow-100");
        const action = findChild(row, "notificationQuickSnooze");
        content.detailsNavigation.focusContent(true);
        verify(!content.detailsNavigation.targets.includes(action));
        tryVerify(() => content.detailsNavigation.contentCommands.includes(action));
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => content.detailsNavigation.commandMenuOpen);
        verify(!action.activeFocus);
        compare(state.activeNotifications.length, 2, "opening commands must not snooze or dismiss");
        keyClick(Qt.Key_Escape);
        tryVerify(() => !content.detailsNavigation.commandMenuOpen);
        content.destroy();
        wait(0);
    }
    function test_backendFailuresRetireLoadingAndPreserveDraft() {
        const state = makeState();
        compare(state.backend.store, state);
        state.historyLoading = true;
        state.setDraft(100, "Keep");
        state.setReplyState(100, true, "");
        state.backend.requests = {
            history: {
                history: true,
                refresh: true
            },
            reply: {
                replyId: 100,
                text: "Keep"
            }
        };
        state.backend.finish("history", {}, "Transport lost");
        verify(!state.historyLoading);
        compare(state.historyError, "Transport lost");
        state.backend.responseReceived("reply", null, "Transport lost");
        verify(!state.replies[100].pending);
        compare(state.drafts[100], "Keep");
        compare(Object.keys(state.backend.requests).length, 0);
    }
}
