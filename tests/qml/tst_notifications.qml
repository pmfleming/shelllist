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
        return state;
    }
    function makeController(state) {
        const controller = createTemporaryObject(controllerComponent, state, {
            notificationState: state,
            width: testCase.width,
            height: testCase.height
        });
        verify(controller !== null);
        projectApps(controller, [app(100, "Chat", 4)]);
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
    function startCenter() {
        const controller = makeController(makeState());
        controller.uiActive = true;
        controller.catalog.reloadApps();
        return controller;
    }
    function rootRequest(controller) {
        const requests = controller.notificationState.backend.requests;
        return Object.keys(requests).find(key => requests[key].center?.view === "apps" && requests[key].center.generation === controller.catalog.rootGeneration);
    }
    function finishApps(controller, value, error, code) {
        controller.notificationState.backend.finish(rootRequest(controller), {notification_center: value}, error || "", code || "");
    }
    function stagedPage() { return Object.assign(appPage([app(200, "First")], "", 0, 1, 2), {anchor_reached: false}); }
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
        const controller = startCenter(), catalog = controller.catalog;
        compare(catalog.anchor, "Chat");
        const first = Array.from({length: 50}, (_, index) => app(100 - index, "App" + index));
        finishApps(controller, Object.assign(appPage(first, "", 0, 50, 100), {anchor_reached: false}));
        verify(catalog.rootBusy);
        compare(catalog.apps.length, 1, "old window remains until replacement is complete");
        const continuation = testCase.calls.filter(call => call.method === "notifications.queryCenter").pop();
        compare(continuation.params.offset, 50);
        compare(continuation.params.revision, "1");
        finishApps(controller, appPage(Array.from({length: 50}, (_, index) => app(50 - index, "Older" + index)), "", 50, null, 100));
        compare(catalog.apps.length, 100);
        verify(!catalog.rootBusy);
        catalog.reloadApps();
        finishApps(controller, appPage([]));
        compare(catalog.apps.length, 0, "refresh replaces, never union-merges deleted rows");
    }
    function test_replyAcknowledgementAndFailure() {
        const state = makeState();
        const key = state.keyFor(100);
        state.setDraft(key, "Hello");
        verify(state.replyNotification(key, "Hello"));
        compare(state.drafts[key], "Hello");
        verify(state.replies[key].pending);
        verify(!state.replyNotification(key, "Hello"));
        const controller = makeController(state);
        controller.catalog.reloadApps();
        finishApps(controller, null, "Read failed");
        verify(!controller.catalog.rootBusy);
        compare(controller.catalog.rootError, "Read failed");
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
        const controller = makeController(state);
        controller.catalog.reloadApps();
        const pending = rootRequest(controller);
        state.connectionLost();
        verify(!state.isLive(reused), "cached rows are not actionable while disconnected");
        state.backend.finish(pending, {notification_center: appPage([app(987)])}, "");
        verify(!controller.catalog.apps.some(app => app.latest.id === 987));
        state.applySnapshot({notifications: {available: true, history_revision: 0}, notification_active: {available: true, revision: 0, notifications: [reused]}});
        verify(state.isLive(reused), "a new generation accepts reset revisions");
        compare(state.drafts[newKey], "New draft");
    }
    function test_coalescedTransientReplacementThenClose() {
        const state = makeState();
        state.applySnapshot({notifications: {available: true, history_revision: 1}, notification_active: {available: true, revision: 1, notifications: [notification(1)]}});
        const controller = makeController(state);
        state.backend.snapshot();
        const oldSnapshot = Object.keys(state.backend.requests).find(id => id.startsWith("snapshot-"));
        state.queueEvent(false, {available: true, revision: 2, notifications: [Object.assign({}, notification(1), {hints: {transient: true}})]});
        state.queueEvent(false, {available: true, revision: 3, notifications: []});
        state.queueEvent(true, {available: true, history_revision: 3});
        state.flushEvents();
        state.backend.finish(oldSnapshot, {snapshot: {notification_active: {available: true, revision: 1, notifications: [notification(1)]}}}, "");
        compare(state.notificationActive.revision, 3, "a stale snapshot cannot undo newer events");
        controller.catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([]), {revision: "3"}));
        compare(controller.catalog.apps.length, 0, "coalescing cannot retain deleted persisted content");
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
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        state.setDraft(100, "Keep draft");
        const old = rootRequest(controller);
        controller.filterText = "needle";
        catalog.reloadApps();
        const current = rootRequest(controller), generation = catalog.rootGeneration;
        const response = {notification_center: appPage([app(900)], "needle")};
        if (data.committed) state.backend.finish(current, response, "", "");
        const visible = JSON.stringify(catalog.apps);
        state.backend.finish(old, {}, "Old read failed", data.outcome === "stale" ? "history-cursor-stale" : "");
        compare(catalog.rootGeneration, generation);
        compare(catalog.rootBusy, !data.committed);
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.rootError, "");
        verify(!state.backend.requests[old]);
        if (!data.committed) state.backend.finish(current, response, "", "");
        state.backend.finish(current, {}, "Late error", "history-cursor-stale");
        compare(catalog.apps[0].latest.id, 900);
        compare(catalog.rootGeneration, generation);
        compare(catalog.rootError, "");
        compare(state.drafts[state.keyFor(100)], "Keep draft");
    }
    function test_queuedRevisionBetweenRefreshPagesDiscardsStaging() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, stagedPage());
        compare(catalog.staging.length, 1);
        compare(JSON.stringify(catalog.apps), visible);
        state.queueEvent(true, {available: true, history_revision: 2});
        finishApps(controller, appPage([app(199, "Second")], "", 1, null, 2));
        compare(state.observedHistoryRevision, 2, "flush queued events before accepting a page");
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.staging.length, 0);
        verify(catalog.rootDirty);
        verify(!catalog.rootBusy);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([app(201)]), {revision: "2"}));
        compare(catalog.apps.map(app => app.latest.id), [201]);
        compare(catalog.revision, "2");
    }
    function test_abandonedRefreshNeverPublishesPartialPages_data() {
        return [{tag: "read-error"}, {tag: "epoch"}];
    }
    function test_abandonedRefreshNeverPublishesPartialPages(data) {
        const controller = startCenter(), catalog = controller.catalog;
        const callsBefore = testCase.calls.length;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, stagedPage());
        const continuation = appPage([app(199, "Second")], "", 1, null, 2);
        if (data.tag === "epoch") continuation.epoch = "after-restart";
        finishApps(controller, continuation, data.tag === "read-error" ? "Read failed" : "");
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.staging.length, 0);
        verify(!catalog.rootBusy);
        compare(testCase.calls.length - callsBefore, 1, "only the initial continuation, none after abandonment");
        verify(testCase.calls.slice(callsBefore).every(call => call.method === "notifications.queryCenter"));
    }
    function test_rejectInvalidCenterPages_data() {
        return [
            {tag: "missing-page", patch: null},
            {tag: "wrong-query", patch: {query: "other"}},
            {tag: "invalid-offset", patch: {next_offset: 42}},
            {tag: "duplicate-records", patch: {apps: [app(99), app(99)], total_apps: 2}},
            {tag: "invalid-id", patch: {apps: [app(4294967296)]}},
            {tag: "missing-app", patch: {apps: [null]}},
            {tag: "too-many-apps", patch: {apps: Array.from({length: 51}, (_, i) => app(i + 1, "App" + i)), total_apps: 51}},
            {tag: "wrong-identity", patch: {apps: [Object.assign(app(99), {key: "Other"})]}},
            {tag: "invalid-count", patch: {apps: [Object.assign(app(99), {count: 1.5})]}},
            {tag: "excessive-count", patch: {apps: [app(99, "Chat", 5201)]}},
            {tag: "missing-token", patch: {epoch: ""}},
            {tag: "wrong-view", patch: {view: "app"}}
        ];
    }
    function test_rejectInvalidCenterPages(data) {
        const controller = startCenter(), catalog = controller.catalog;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, data.patch === null ? null : Object.assign(appPage([app(99)]), data.patch));
        compare(JSON.stringify(catalog.apps), visible);
        verify(catalog.rootError.length > 0);
        verify(!catalog.rootBusy);
        compare(catalog.staging.length, 0);
    }
    function test_detailValidationKeepsLastCoherentRecord_data() {
        return [{tag: "wrong-app", patch: {app_key: "Other"}},
            {tag: "wrong-record-app", patch: {entries: [preview(100, "Other")]}},
            {tag: "duplicate-record", patch: {entries: [preview(100), preview(100)]}},
            {tag: "unbounded-preview", patch: {overview: Array.from({length: 4}, (_, i) => preview(i + 1))}},
            {tag: "wrong-pages", patch: {pages: 7}},
            {tag: "invalid-page", patch: {page: 0}},
            {tag: "invalid-count", patch: {count: -1}},
            {tag: "excessive-total", patch: {total_count: 5201}},
            {tag: "wrong-selected-record", patch: {selected: record(99)}}];
    }
    function test_detailValidationKeepsLastCoherentRecord(data) {
        const controller = makeController(makeState());
        controller.readRecord(preview(100)); projectDetail(controller, [record(100)]);
        const before = JSON.stringify(controller.catalog.detail);
        controller.catalog.acceptDetail(Object.assign({}, controller.catalog.detail, data.patch));
        compare(JSON.stringify(controller.catalog.detail), before);
        verify(controller.catalog.detailError.length > 0);
        verify(!controller.messageCommandsEnabled);
    }
    function test_hidingCenterRetiresStagingWithoutReplayingReads() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, stagedPage());
        const pending = rootRequest(controller), calls = testCase.calls.length;
        controller.uiActive = false;
        state.backend.finish(pending, {notification_center: appPage([app(199, "Second")], "", 1, null, 2)}, "", "");
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.staging.length, 0);
        verify(!catalog.rootBusy);
        wait(150);
        compare(testCase.calls.length, calls);
    }
    function test_stalePagesNeverMixVisibleRevisionsAndGapsRefreshReads() {
        const controller = startCenter(), catalog = controller.catalog, state = controller.notificationState;
        finishApps(controller, appPage([app(100), app(3, "Mail")], "", 0, 2, 3));
        catalog.rootDirty = false; catalog.loadMore();
        finishApps(controller, null, "History changed", "history-cursor-stale");
        verify(catalog.rootDirty);
        compare(catalog.apps.length, 2);
        catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([app(101)]), {revision: "2"}));
        compare(catalog.revision, "2");
        compare(catalog.apps.length, 1, "refresh removes absent apps");
        catalog.acceptApps({offset: 1, replacing: false}, Object.assign(appPage([app(99, "Other")], "", 1, null, 2), {revision: "3"}));
        compare(catalog.apps.length, 1);
        verify(catalog.rootDirty);
        projectApps(controller, [app(100)]);
        for (const page of [appPage([], "", 1, 1, 2), appPage([app(100)], "", 1, null, 2), appPage([app(0)], "", 1, null, 2)]) {
            catalog.acceptApps({offset: 1, replacing: false}, page);
            verify(catalog.rootError.length > 0);
            compare(catalog.apps.length, 1);
        }
        state.connectionLost(); catalog.reloadApps();
        finishApps(controller, Object.assign(appPage([]), {epoch: "new-daemon", revision: "0"}));
        compare(catalog.epoch, "new-daemon");
        compare(catalog.apps.length, 0);
        catalog.rootDirty = false; catalog.detailDirty = false;
        state.backend.eventGapDetected("notifications.changed", {event: "lagged"});
        verify(catalog.rootDirty && catalog.detailDirty, "a gap refreshes the active reader even before the next revision");
    }
}
