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
                    key: "inline-reply",
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
    function page(records, cursor, revision, query, anchorReached) {
        return {records: records, next_cursor: cursor || null, epoch: "test-epoch", revision: revision || "1", query: query || "", anchor_reached: anchorReached !== false, scope_limit: 5000};
    }
    // Presentation tests supply authoritative pages, not a second native catalog.
    function project(state, records, cursor) {
        state.historyStaging = [];
        state.stagingEpoch = "";
        state.stagingRevision = "";
        state.applyHistory(page(records, cursor, "1", state.historyQuery), true, null);
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
        project(state, [record(100), record(3), record(2), record(1)]);
        return state;
    }
    function makeController(state) {
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state,
            width: testCase.width,
            height: testCase.height
        });
        verify(controller !== null);
        projectApps(controller, [app(100, "Chat", state.history.length)]);
        return controller;
    }
    function preview(id, name) { return Object.assign(notification(id, name), {app_key: name || "Chat", app_icon: "", closed_unix_ms: null}); }
    function app(id, name, count) { return {key: name || "Chat", count: count || 1, total_count: count || 1, latest: preview(id, name)}; }
    function appPage(apps, query, offset, next, total) {
        return {view: "apps", epoch: "test-epoch", revision: "1", query: query || "", apps: apps,
            offset: offset || 0, next_offset: next === undefined ? null : next, total_apps: total || apps.length, anchor_reached: true};
    }
    function projectApps(controller, apps) {
        controller.catalog.staging = [];
        controller.catalog.stagingEpoch = "";
        controller.catalog.stagingRevision = "";
        controller.catalog.acceptApps({offset: 0, replacing: true}, appPage(apps, controller.catalog.query));
        compare(controller.catalog.rootError, "");
        controller.rebuildRecords();
    }
    function projectDetail(controller, records, count, number) {
        controller.catalog.detailBusy = false;
        controller.catalog.acceptDetail({view: "app", epoch: "test-epoch", revision: "1", query: controller.catalog.query,
            app_key: controller.selectedAppKey, count: count || records.length, total_count: count || records.length,
            page: number || 1, pages: Math.max(1, Math.ceil((count || records.length) / 5)),
            overview: records.slice(0, 3).map(r => preview(r.notification.id, controller.selectedAppKey)),
            entries: records.slice(0, 5).map(r => preview(r.notification.id, controller.selectedAppKey)),
            selected: records.find(r => r.notification.id + ":" + r.notification.created_unix_ms === controller.selectedKey) || null});
    }
    function descendants(item) {
        return Array.from(item.children || []).reduce((items, child) => items.concat(descendants(child)), [item]);
    }
    function test_indexCommandsRenderSymbolsAndRetainRoutes() {
        const controller = makeController(makeState());
        controller.uiActive = true;
        controller.openDetails();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(150);
        projectDetail(controller, [record(100), record(3), record(2)], 12);
        verify(waitForRendering(content));
        for (const name of ["list", "article"]) {
            const glyph = descendants(content).find(item => item.glyph === name);
            verify(glyph !== undefined);
            compare(glyph.symbol, name, "semantic command uses the symbol font, not literal fallback text");
            verify(glyph.implicitWidth <= glyph.font.pixelSize * 1.5);
        }
        mouseClick(findChild(content, "detailAction:browse"));
        tryCompare(controller, "detailsTab", "notifications");
        verify(waitForRendering(content));
        const pageGlyph = descendants(content).find(item => item.glyph === "find_in_page");
        verify(pageGlyph !== undefined);
        compare(pageGlyph.symbol, "find_in_page");
        verify(!content.detailsNavigation.targets.includes(findChild(content, "notificationRead-100:100000")));
        content.destroy(); wait(0);
    }
    function test_previewsPromoteMessageContentWithoutChangingIdentity() {
        const controller = makeController(makeState());
        controller.uiActive = true; controller.openDetails();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(150);
        projectDetail(controller, [record(100), record(3)]);
        const entries = [Object.assign(preview(100), {summary: "Chat", body: "Payment received", closed_unix_ms: 100001}),
            Object.assign(preview(3), {summary: "Unique subject", body: "<b>Plain message</b> ".repeat(30)})];
        controller.catalog.acceptDetail(Object.assign({}, controller.catalog.detail, {overview: entries, entries: entries}));
        verify(waitForRendering(content));
        const title = findChild(content, "notificationPreviewTitle-100:100000");
        const meta = findChild(content, "notificationPreviewMeta-100:100000");
        compare(title.text, "Payment received");
        verify(title.font.pixelSize > meta.font.pixelSize);
        verify(!findChild(content, "notificationPreviewBody-100:100000").visible);
        const body = findChild(content, "notificationPreviewBody-3:3000");
        compare(body.textFormat, Text.PlainText);
        verify(body.lineCount <= 2);
        verify(body.height > 0);
        controller.setDetailsTab("notifications");
        verify(waitForRendering(content));
        compare(findChild(content, "notificationPreviewTitle-100:100000").text, "Payment received");
        verify(!body.visible);
        mouseClick(findChild(content, "notificationRead-100:100000"));
        tryCompare(controller, "selectedKey", "100:100000");
        compare(controller.detailsTab, "message");
        content.destroy(); wait(0);
    }
    function test_paneSpacingAndCompactReadGeometry_data() {
        return [{tag: "wide", width: 1280, height: 600}, {tag: "narrow", width: 900, height: 480}];
    }
    function test_paneSpacingAndCompactReadGeometry(data) {
        const controller = makeController(makeState());
        controller.availableScreenWidth = data.width;
        controller.uiActive = true; controller.openDetails();
        controller.width = controller.currentWindowWidth;
        controller.height = data.height;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: controller.currentWindowWidth, height: data.height});
        wait(150); projectDetail(controller, [record(100), record(3)]);
        verify(waitForRendering(content));
        compare(content.width, controller.currentWindowWidth);
        compare(content.height, data.height);
        const list = findChild(content, "resultListView");
        const pane = content.listItem;
        const directY = list.mapToItem(pane, 0, 0).y;
        verify(Math.abs(directY - pane.headerHeight - pane.spacing) <= 1, "no invisible options row below search");
        const primary = findChild(content, "detailAction:browse");
        const read = findChild(content, "notificationRead-100:100000");
        compare(read.width, 32); compare(read.height, 32);
        verify(primary.width > read.width);
        const title = findChild(content, "notificationPreviewTitle-100:100000");
        const left = title.mapToItem(content.detailsItem, 0, 0).x;
        const right = read.mapToItem(content.detailsItem, read.width, 0).x;
        verify(left >= 12);
        verify(right <= content.detailsItem.width - 12);
        verify(title.mapToItem(content.detailsItem, title.width, 0).x < read.mapToItem(content.detailsItem, 0, 0).x);
        controller.returnSurface = "activity";
        tryVerify(() => findChild(content, "notificationsBackToAgenda") !== null);
        verify(waitForRendering(content));
        verify(list.mapToItem(pane, 0, 0).y > directY + 30, "real Back action keeps its space");
        let returned = false;
        controller.backRequested.connect(() => returned = true);
        mouseClick(findChild(content, "notificationsBackToAgenda"));
        verify(returned);
        content.destroy(); wait(0);
    }
    function test_dndAcknowledgementAndRetry() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {
            store: state
        });
        compare(state.dndDurationMinutes, 30);
        state.setDndDuration(60);
        compare(state.dndDurationMinutes, 60);
        compare(state.backend.dndCalls, 0);
        const now = Date.now();
        verify(state.setDndEnabled(true));
        verify(state.backend.requestedDnd);
        verify(state.backend.requestedUntil >= now + 3600000);
        verify(!state.notifications.dnd, "daemon owns acknowledged DND state");
        verify(state.dndPending);
        verify(!state.setDndEnabled(false), "one outstanding DND request");
        state.finishDnd(null, "Disconnected");
        compare(state.dndError, "Disconnected");
        verify(!state.notifications.dnd);
        state.retryDnd();
        compare(state.backend.dndCalls, 2);
        state.finishDnd({available: true, dnd: true}, "");
        verify(state.notifications.dnd);
        state.setDndDuration(0);
        compare(state.backend.requestedUntil, null);
        verify(state.dndPending);
        state.finishDnd({available: true, dnd: true, dnd_until_unix_ms: null}, "");
        state.setDndEnabled(false);
        verify(!state.backend.requestedDnd);
        compare(state.backend.requestedUntil, null);
    }
    function test_refreshStagesAuthoritativePagesUntilVisibleAnchor() {
        const state = makeState();
        state.backend = createTemporaryObject(fakeBackendComponent, state, {store: state});
        state.historyEnabled = true;
        state.reloadHistory();
        compare(state.historyAnchor.id, 1);
        const first = Array.from({length: 50}, (_, index) => record(100 - index));
        state.applyHistory(page(first, "opaque-next", "2", "", false), true, null);
        compare(state.backend.requestedCursor, "opaque-next");
        verify(state.backend.requestedRefresh);
        verify(state.historyLoading);
        compare(state.history.length, 4, "old window remains until replacement is complete");
        const rest = Array.from({length: 50}, (_, index) => record(50 - index));
        state.applyHistory(page(rest, null, "2"), true, "opaque-next");
        compare(state.history.length, 100);
        verify(!state.historyLoading);
        state.reloadHistory();
        state.applyHistory(page([], null, "3"), true, null);
        compare(state.history.length, 0, "refresh removes absent rows instead of union-merging them");
    }
    function test_replyAcknowledgementAndFailure() {
        const state = makeState();
        const key = state.keyFor(100);
        state.setDraft(key, "Hello");
        verify(state.replyNotification(key, "Hello"));
        compare(state.drafts[key], "Hello");
        verify(state.replies[key].pending);
        verify(!state.replyNotification(key, "Hello"));
        state.reloadHistory();
        const history = Object.keys(state.backend.requests).find(id => id.startsWith("history-"));
        state.backend.finish(history, {}, "Read failed");
        verify(!state.historyLoading);
        compare(state.historyError, "Read failed");
        verify(state.replies[key].pending, "a read failure cannot retire the reply");
        const failed = Object.keys(state.backend.requests).find(id => id.startsWith("reply-"));
        state.backend.acceptSharedResponse(failed, null, "Connection lost");
        compare(state.drafts[key], "Hello");
        verify(!state.replies[key].pending);
        compare(state.replies[key].error, "Connection lost");
        verify(state.replyNotification(key, "Hello"));
        const retried = Object.keys(state.backend.requests).find(id => id.startsWith("reply-"));
        state.backend.finish(retried, {}, "");
        compare(state.drafts[key], undefined);
        state.setDraft(key, "Newer draft");
        state.finishReply(key, "Older draft", "");
        compare(state.drafts[key], "Newer draft");
    }
    function test_liveUpdateRetainsReplyDelegateAndFocus() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        controller.readRecord(preview(100));
        projectDetail(controller, [record(100), record(1)]);
        state.setDraft(100, "Draft");
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(50);
        const row = findChild(content, "notificationHistoryRow-100");
        verify(row !== null);
        const field = findChild(row, "notificationReplyInput");
        field.focusInput(false);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_T);
        compare(state.drafts[state.keyFor(100)], "Draft", "typing stays local");
        projectApps(controller, [app(101, "Chat", 500)]);
        projectDetail(controller, [record(101), record(100), record(1)], 500);
        wait(50);
        compare(findChild(content, "notificationHistoryRow-100"), row);
        verify(field.inputActiveFocus);
        compare(field.text, "Draftt");
        compare(controller.notificationModel.count, 1, "a 500-message app is still one result");
        keyClick(Qt.Key_Return);
        compare(state.drafts[state.keyFor(100)], "Draftt");
        field.focusInput(false);
        keyClick(Qt.Key_End);
        keyClick(Qt.Key_X);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(controller, "detailsTab", "overview");
        compare(state.drafts[state.keyFor(100)], "Draftt", "tab switch discards only the unsaved edit");
        keyClick(Qt.Key_Tab, Qt.ControlModifier | Qt.ShiftModifier);
        tryCompare(controller, "detailsTab", "message");
        tryVerify(() => findChild(content, "notificationReplyInput") !== null);
        compare(findChild(content, "notificationReplyInput").text, "Draftt");
        content.destroy(); wait(0);
    }
    function test_actionsOnlyBelongToExpandedMessage() {
        const state = makeState();
        const live = notification(100);
        live.actions = [{key: "default", label: "Open"}, {key: "mail-reply-sender", label: "Reply in app"}, {key: "inline-reply", label: "Reply here"}];
        state.notificationActive = {notifications: [live]};
        const controller = makeController(state);
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        projectDetail(controller, [{notification: live}, record(3)]);
        content.listItem.focusList();
        const sent = () => testCase.calls.filter(call => call.method === "notifications.invokeAction");
        const before = sent().length;
        keyClick(Qt.Key_O, Qt.AltModifier);
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(sent().length, before);
        verify(!controller.detailsOpen);
        verify(!findChild(content, "detailAction:open"));
        keyClick(Qt.Key_Return);
        tryCompare(controller, "detailsTab", "notifications");
        verify(controller.detailsOpen);
        compare(sent().length, before, "app Enter only reviews, never invokes a hidden message");
        tryVerify(() => findChild(content, "notificationRead-100:100000") !== null);
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => content.detailsNavigation.commandMenuOpen);
        projectDetail(controller, [{notification: live}, record(2)]);
        tryVerify(() => !content.detailsNavigation.commandMenuOpen, 1000, "changed Read targets close the menu before Enter can retarget");
        verify(waitForRendering(content));
        mouseClick(findChild(content, "notificationRead-100:100000"));
        tryCompare(controller, "detailsTab", "message");
        projectDetail(controller, [{notification: live}, record(3)]);
        compare(controller.selectedKey, "100:100000");
        compare(controller.catalog.detailError, "");
        verify(controller.messageCommandsEnabled);
        tryVerify(() => findChild(content, "detailAction:open") !== null);
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(sent().length, before + 1);
        keyClick(Qt.Key_O, Qt.AltModifier);
        compare(sent().length, before + 1, "pending action cannot repeat");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("action-")), {}, "App unavailable");
        compare(state.lastError, "App unavailable");
        keyClick(Qt.Key_J, Qt.AltModifier);
        tryVerify(() => content.detailsNavigation.commandMenuOpen);
        const dismissCount = testCase.calls.filter(call => call.method === "notifications.dismiss").length;
        keyClick(Qt.Key_D, Qt.AltModifier);
        compare(testCase.calls.filter(call => call.method === "notifications.dismiss").length, dismissCount);
        keyClick(Qt.Key_Return);
        compare(sent().length, before + 2);
        compare(sent()[before + 1].params.action_key, "mail-reply-sender");
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("action-")), {}, "");
        keyClick(Qt.Key_R, Qt.AltModifier);
        tryVerify(() => findChild(content, "notificationReplyInput") !== null && findChild(content, "notificationReplyInput").inputActiveFocus);
        const field = findChild(content, "notificationReplyInput");
        keyClick(Qt.Key_H); keyClick(Qt.Key_I);
        const repliesBefore = testCase.calls.filter(call => call.method === "notifications.reply").length;
        keyClick(Qt.Key_Return);
        compare(state.drafts[controller.selectedKey], "hi");
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore);
        keyClick(Qt.Key_R, Qt.AltModifier);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore + 1);
        state.backend.finish(Object.keys(state.backend.requests).find(key => key.startsWith("reply-")), {}, "");
        compare(field.text, "");
        controller.closeDetails(); content.listItem.focusList(); wait(20);
        compare(content.detailsNavigation.commandButtons.filter(button => button.accessKey === "O").length, 0);
        keyClick(Qt.Key_R, Qt.AltModifier); keyClick(Qt.Key_D, Qt.AltModifier);
        verify(!controller.detailsOpen);
        compare(testCase.calls.filter(call => call.method === "notifications.reply").length, repliesBefore + 1);
        controller.openDetails(); controller.readRecord(preview(3));
        projectDetail(controller, [record(3)]); wait(20);
        verify(!controller.selectedLive);
        verify(!controller.openSelected());
        compare(sent().length, before + 2);
        content.destroy(); wait(0);
    }
    function test_pageFieldUsesSharedTransactionsAndKeepsAppListFixed() {
        const state = makeState();
        const controller = makeController(state);
        projectApps(controller, [app(100, "Chat", 500), app(1, "Mail", 1)]);
        controller.uiActive = true;
        controller.primarySelected();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(150);
        projectDetail(controller, [record(100), record(99), record(98), record(97), record(96)], 500);
        const pageField = findChild(content, "notificationPage");
        verify(pageField !== null);
        content.listItem.focusList(); keyClick(Qt.Key_Tab); keyClick(Qt.Key_Return);
        tryVerify(() => pageField.inputActiveFocus);
        const reads = () => testCase.calls.filter(call => call.method === "notifications.queryCenter" && call.params.view === "app");
        let before = reads().length;
        keyClick(Qt.Key_A, Qt.ControlModifier); keyClick(Qt.Key_2);
        compare(reads().length, before, "typing a page never queries");
        keyClick(Qt.Key_Escape);
        compare(reads().length, before);
        compare(pageField.text, "1");
        pageField.focusInput(true);
        keyClick(Qt.Key_9); keyClick(Qt.Key_9); keyClick(Qt.Key_9); keyClick(Qt.Key_Return);
        compare(reads().length, before);
        verify(controller.catalog.pageError.length > 0);
        pageField.focusInput(true); keyClick(Qt.Key_2); keyClick(Qt.Key_Tab);
        compare(reads().length, before + 1, "Tab saves the page");
        compare(reads().pop().params.page, 2);
        compare(reads().pop().params.page_anchor, null);
        controller.catalog.requestDetail(true);
        compare(reads().pop().params.page, 2);
        compare(reads().pop().params.page_anchor, null, "refresh cannot replace an in-flight explicit seek with an old anchor");
        projectDetail(controller, [record(95), record(94), record(93), record(92), record(91)], 500, 2);
        compare(controller.notificationModel.count, 2);
        compare(controller.catalog.detail.entries.length, 5);
        compare(controller.catalog.detail.overview.length, 3);
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(controller, "detailsTab", "overview");
        compare(controller.notificationModel.count, 2);
        controller.readRecord(preview(95));
        projectDetail(controller, [record(95)], 500, 2);
        keyClick(Qt.Key_J, Qt.AltModifier);
        verify(!content.detailsNavigation.commandMenuOpen, "hidden index Read commands cannot leak into Message's menu");
        content.listItem.focusList(); keyClick(Qt.Key_Down);
        compare(controller.selectedAppKey, "Mail");
        keyClick(Qt.Key_Up);
        compare(controller.selectedAppKey, "Chat");
        compare(controller.detailsTab, "message");
        compare(controller.catalog.page, 2);
        controller.closeDetails(); content.listItem.focusList(); keyClick(Qt.Key_Return);
        compare(controller.detailsTab, "notifications", "app primary always reviews the index, not remembered Message");
        content.destroy(); wait(0);
    }
    function test_centerRefreshNeverPublishesPartialAppPages() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        tryCompare(controller.catalog, "rootBusy", true);
        const requestFor = () => Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps" && state.backend.requests[key].center.generation === controller.catalog.rootGeneration);
        const first = appPage(Array.from({length: 50}, (_, index) => app(1000 - index, "App" + index)), "", 0, 50, 51);
        first.anchor_reached = false;
        state.backend.finish(requestFor(), {notification_center: first}, "", "");
        compare(controller.visibleApps.length, 1, "incomplete refresh stays private");
        tryVerify(() => requestFor() !== undefined);
        state.backend.finish(requestFor(), {}, "Cannot read history", "unavailable");
        compare(controller.visibleApps.length, 1);
        compare(controller.selectedAppKey, "Chat");
        compare(controller.catalog.staging.length, 0);
        verify(controller.catalog.rootError.length > 0);
        controller.refresh();
        tryVerify(() => requestFor() !== undefined);
        state.backend.finish(requestFor(), {notification_center: appPage([app(99, "Mail")])}, "", "");
        tryCompare(controller, "selectedAppKey", "Mail");
    }
    function test_emptyCenterSettlesAndMalformedSnapshotsFailClosed() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        const catalog = controller.catalog;
        tryCompare(catalog, "rootBusy", true);
        const request = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps");
        state.backend.finish(request, {notification_center: appPage([])}, "", "");
        tryCompare(controller.notificationModel, "count", 0);
        wait(180);
        compare(catalog.detailDirty, false);
        compare(catalog.rootDirty, false);
        verify(!catalog.rootBusy && !catalog.detailBusy);
        const before = testCase.calls.filter(call => call.method === "notifications.queryCenter").length;
        wait(180);
        compare(testCase.calls.filter(call => call.method === "notifications.queryCenter").length, before, "empty results do not poll continuously");
        catalog.acceptApps({offset: 0, replacing: true}, appPage([app(100), app(100)]));
        verify(catalog.rootError.length > 0);
        compare(catalog.apps.length, 0);
        projectApps(controller, [app(100, "Chat", 2)]);
        controller.readRecord(preview(100));
        projectDetail(controller, [record(100)], 2);
        verify(controller.selectedNotification !== null);
        catalog.acceptDetail(Object.assign({}, catalog.detail, {selected: record(1)}));
        verify(catalog.detailError.length > 0);
        verify(!controller.messageCommandsEnabled);
        controller.readRecord(preview(1));
        catalog.acceptDetail(Object.assign({}, catalog.detail, {selected: null}));
        compare(controller.selectedKey, "1:1000", "missing records retain an explicit unavailable Message, never retarget");
        verify(controller.selectedRecord === null);
    }
    function test_recordIdentityAndConnectionGenerationFenceDraftsAndHistory() {
        const state = makeState();
        const oldKey = state.keyFor(100);
        state.setDraft(oldKey, "Old draft");
        verify(state.replyNotification(oldKey, "Old draft"));
        const pendingReply = Object.keys(state.backend.requests).find(key => key.startsWith("reply-"));
        const reused = Object.assign({}, notification(100), {created_unix_ms: 999999});
        state.notificationActive = {available: true, notifications: [reused]};
        const newKey = state.keyFor(100);
        verify(oldKey !== newKey);
        state.setDraft(newKey, "New draft");
        state.backend.finish(pendingReply, {}, "");
        compare(state.drafts[oldKey], undefined);
        compare(state.drafts[newKey], "New draft", "old acknowledgement cannot clear another conversation");
        verify(!state.isLive(notification(100)));
        verify(!state.replyNotification(oldKey, "Stale"));
        state.reloadHistory();
        const pendingHistory = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.connectionLost();
        verify(!state.isLive(reused), "cached rows are not actionable while disconnected");
        state.backend.finish(pendingHistory, {notification_page: page([record(987)])}, "");
        verify(!state.history.some(record => record.history_id === 987));
        state.applySnapshot({notifications: {available: true, history_revision: 0}, notification_active: {available: true, revision: 0, notifications: [reused]}});
        verify(state.isLive(reused), "a new generation accepts reset revisions");
        compare(state.drafts[newKey], "New draft");
    }
    function test_coalescedTransientReplacementThenClose() {
        const state = makeState();
        state.applySnapshot({notifications: {available: true, history_revision: 1}, notification_active: {available: true, revision: 1, notifications: [notification(1)]}});
        project(state, [record(1)]);
        state.backend.snapshot();
        const oldSnapshot = Object.keys(state.backend.requests).find(id => id.startsWith("snapshot-"));
        state.queueEvent(false, {available: true, revision: 2, notifications: [Object.assign({}, notification(1), {hints: {transient: true}})]});
        state.queueEvent(false, {available: true, revision: 3, notifications: []});
        state.queueEvent(true, {available: true, history_revision: 3});
        state.flushEvents();
        state.backend.finish(oldSnapshot, {snapshot: {notification_active: {available: true, revision: 1, notifications: [notification(1)]}}}, "");
        compare(state.notificationActive.revision, 3, "a stale snapshot cannot undo newer events");
        state.reloadHistory();
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(request, {notification_page: page([], null, "3")}, "", "");
        compare(state.recentNotifications.length, 0, "coalescing cannot retain deleted persisted content");
    }
    function test_appPrependAndPageAppendPreserveViewportAnchor() {
        const state = makeState();
        const controller = makeController(state);
        const apps = Array.from({length: 45}, (_, index) => app(1000 - index, "App" + index, 500));
        projectApps(controller, apps);
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        const list = findChild(content, "resultListView");
        tryCompare(list, "count", 45);
        controller.select(12); wait(30);
        list.positionViewAtIndex(10, ListView.Beginning);
        const anchor = content.listItem.sessionState().viewport;
        verify(anchor !== null);
        const selected = controller.selectedAppKey;
        projectApps(controller, [app(2000, "New app")].concat(apps));
        wait(40);
        compare(controller.selectedAppKey, selected);
        compare(content.listItem.sessionState().viewport.key, anchor.key);
        verify(Math.abs(content.listItem.sessionState().viewport.offset - anchor.offset) < 1);
        controller.catalog.acceptApps({offset: 46, replacing: false}, appPage(Array.from({length: 50}, (_, index) => app(900 - index, "Older" + index)), "", 46, null, 96));
        wait(40);
        compare(content.listItem.sessionState().viewport.key, anchor.key);
        compare(list.count, 96);
        content.destroy(); wait(0);
    }
    function test_keyboardSearchUsesNativeCatalogAndRejectsSupersededReplies() {
        const state = makeState();
        const controller = makeController(state);
        controller.uiActive = true;
        const catalog = controller.catalog;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        tryCompare(catalog, "rootBusy", true);
        const initial = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps");
        state.setDraft(100, "Keep my draft");
        content.listItem.focusSearch();
        for (const key of [Qt.Key_N, Qt.Key_E, Qt.Key_E, Qt.Key_D, Qt.Key_L, Qt.Key_E]) keyClick(key);
        compare(controller.filterText, "needle");
        compare(catalog.query, "needle");
        state.backend.finish(initial, {notification_center: appPage([app(888)])}, "", "");
        compare(catalog.apps.length, 0);
        tryCompare(catalog, "rootBusy", true);
        const request = Object.keys(state.backend.requests).find(key => state.backend.requests[key].center?.view === "apps" && state.backend.requests[key].center.generation === catalog.rootGeneration);
        const call = testCase.calls.filter(call => call.method === "notifications.queryCenter" && call.params.view === "apps").pop();
        compare(call.params.query, "needle");
        compare(call.params.offset, 0);
        const found = app(900, "Unloaded app", 1);
        found.latest.summary = "Needle from previously unloaded history";
        state.backend.finish(request, {notification_center: appPage([found], "needle")}, "", "");
        tryCompare(controller.notificationModel, "count", 1);
        compare(controller.selectedAppKey, "Unloaded app");
        compare(state.drafts["100:100000"], "Keep my draft");
        content.destroy(); wait(0);
    }
    function test_oldQueryCompletionCannotRetireReplacement_data() {
        // Successful old-query replies are covered by keyboard search. Keep
        // errors on either side of replacement publication, not the full product.
        return [{tag: "failure-pending", committed: false, outcome: "failure"},
                {tag: "stale-after-commit", committed: true, outcome: "stale"}];
    }
    function test_oldQueryCompletionCannotRetireReplacement(data) {
        const state = makeState();
        state.setDraft(100, "Keep draft");
        state.reloadHistory();
        const old = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.setHistoryQuery("needle");
        state.reloadHistory();
        const current = Object.keys(state.backend.requests).find(key => key !== old && key.startsWith("history-"));
        const generation = state.historyGeneration;
        const response = {notification_page: page([record(900)], null, "2", "needle")};
        if (data.committed) state.backend.finish(current, response, "", "");
        const visible = JSON.stringify(state.history);
        state.backend.finish(old, {notification_page: page([record(888)])}, "Old read failed", data.outcome === "stale" ? "history-cursor-stale" : "");
        compare(state.historyGeneration, generation);
        compare(state.historyLoading, !data.committed, "an old error cannot retire the current read");
        compare(JSON.stringify(state.history), visible);
        compare(state.historyError, "");
        verify(!state.backend.requests[old]);
        if (!data.committed) state.backend.finish(current, response, "", "");
        // Duplicate delivery is ignored after request ownership was consumed.
        state.backend.finish(current, {notification_page: page([record(777)])}, "Late error", "history-cursor-stale");
        compare(state.history[0].notification.id, 900);
        compare(state.historyGeneration, generation);
        compare(state.historyError, "");
        compare(state.drafts[state.keyFor(100)], "Keep draft");
    }
    function test_queuedRevisionBetweenRefreshPagesDiscardsStaging() {
        const state = makeState();
        state.applySummary({available: true, history_revision: 1});
        state.historyEnabled = true;
        state.reloadHistory();
        const first = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        const visible = JSON.stringify(state.history);
        state.backend.finish(first, {notification_page: page([record(200)], "tail", "1", "", false)}, "", "");
        const tail = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        compare(state.historyStaging.length, 1);
        compare(JSON.stringify(state.history), visible);
        state.queueEvent(true, {available: true, history_revision: 2});
        state.backend.finish(tail, {notification_page: page([record(199)], null, "1")}, "", "");
        compare(state.observedHistoryRevision, 2, "queued events are flushed before accepting a page");
        compare(JSON.stringify(state.history), visible, "stale staging is never published");
        compare(state.historyStaging.length, 0);
        verify(state.historyDirty);
        verify(!state.historyLoading);
        state.reloadHistory();
        const replacement = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(replacement, {notification_page: page([record(201)], null, "2")}, "", "");
        compare(state.history.map(item => item.notification.id), [201]);
        compare(state.historyRevision, "2");
    }
    function test_abandonedRefreshNeverPublishesPartialPages_data() {
        return [{tag: "read-error"}, {tag: "epoch"}];
    }
    function test_abandonedRefreshNeverPublishesPartialPages(data) {
        const state = makeState();
        state.historyEnabled = true;
        const visible = JSON.stringify(state.history);
        const callsBefore = testCase.calls.length;
        state.reloadHistory();
        const first = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(first, {notification_page: page([record(200)], "tail", "2", "", false)}, "", "");
        const tail = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        const continuation = page([record(199)], "older", "2", "", false);
        if (data.tag === "epoch") continuation.epoch = "after-restart";
        state.backend.finish(tail, {notification_page: continuation}, data.tag === "read-error" ? "Read failed" : "", "");
        compare(JSON.stringify(state.history), visible);
        compare(state.historyStaging.length, 0);
        verify(!state.historyLoading);
        compare(testCase.calls.length - callsBefore, 2, "no further continuation after abandonment");
        verify(testCase.calls.slice(callsBefore).every(call => call.method === "notifications.queryHistory"), "recovery is read-only");
    }
    function test_rejectInvalidHistoryPages_data() {
        return [
            {tag: "missing-page", patch: null},
            {tag: "wrong-query", patch: {query: "other"}},
            {tag: "invalid-cursor", patch: {next_cursor: 42}},
            {tag: "duplicate-records", patch: {records: [record(99), record(99)]}},
            {tag: "invalid-id", patch: {records: [record(4294967296)]}}
        ];
    }
    function test_rejectInvalidHistoryPages(data) {
        const state = makeState();
        const visible = JSON.stringify(state.history);
        state.reloadHistory();
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(request, {notification_page: data.patch === null ? null : Object.assign(page([record(99)]), data.patch)}, "", "");
        compare(JSON.stringify(state.history), visible);
        verify(state.historyError.length > 0);
        verify(!state.historyLoading);
        compare(state.historyStaging.length, 0);
    }
    function test_cursorInvalidationAndMalformedPagesNeverMixVisibleRevisions() {
        const state = makeState();
        project(state, [record(100), record(3)], "old-cursor");
        state.historyDirty = false;
        state.loadMoreHistory();
        const request = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(request, {}, "History changed", "history-cursor-stale");
        verify(state.historyDirty);
        compare(state.history.length, 2, "stale reads retain the current visible window until refresh");
        verify(!state.historyHasMore);
        state.reloadHistory();
        const refresh = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        state.backend.finish(refresh, {notification_page: page([record(101), record(100)], "new-cursor", "2")}, "", "");
        compare(state.historyRevision, "2");
        verify(!state.history.some(item => item.history_id === 3), "refresh removes absent records");
        state.applyHistory(page([record(99)], null, "3"), false, "new-cursor");
        compare(state.history.length, 2, "a different page revision is never appended");
        verify(state.historyDirty);
        project(state, [record(100)], "cursor");
        state.applyHistory(page([], "cursor"), false, "cursor");
        verify(state.historyError.length > 0, "non-advancing pages fail instead of looping");
        compare(state.history.length, 1);
        state.applyHistory(page([record(100)], null), false, "cursor");
        compare(state.history.length, 1, "duplicate pages are rejected, not silently deduplicated");
        state.applyHistory(page([{notification: {id: 99}}]), false, "cursor");
        compare(state.history.length, 1, "malformed identities cannot enter the keyed model");
        // Reconnect can legitimately reset revision numbers and changes epoch.
        state.connectionLost();
        state.reloadHistory();
        const reconnect = Object.keys(state.backend.requests).find(key => key.startsWith("history-"));
        const replacement = page([], null, "0");
        replacement.epoch = "new-daemon";
        state.backend.finish(reconnect, {notification_page: replacement}, "", "");
        compare(state.historyEpoch, "new-daemon");
        compare(state.history.length, 0, "missed deletion events are repaired by authoritative replacement");
    }
}
