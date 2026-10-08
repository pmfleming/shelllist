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
            selected: records.find(r => r.notification.id + ":" + r.notification.created_unix_ms === controller.catalog.selectedKey) || null});
        projectTimeline(controller, records.map(r => preview(r.notification.id, controller.selectedAppKey)));
    }
    function projectTimeline(controller, previews) {
        controller.timeline.busy = false;
        controller.timeline.requestedDate = previews.length > 3 ? "older" : "";
        controller.timeline.collapsed = previews.length <= 3;
        controller.timeline.snapshot = {recent: previews.slice(0, 3), dates: ["today", "week", "month", "older"].map(key => ({key: key, count: key === "older" ? Math.max(0, previews.length - 3) : 0})), date: controller.timeline.requestedDate, next_offset: null};
        controller.timeline.entries = previews.slice(3).map(p => ({key: p.id + ":" + p.created_unix_ms, preview: p, members: [{id: p.id, created: p.created_unix_ms}]}));
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
    function test_previewHierarchyAndPassiveCards_data() {
        return [{tag: "narrow", width: 900}];
    }
    function test_previewHierarchyAndPassiveCards(data) {
        const controller = makeController(makeState());
        controller.availableScreenWidth = data.width;
        controller.uiActive = true; controller.openDetails();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: controller.currentWindowWidth, height: 600});
        wait(150);
        projectDetail(controller, [record(100), record(3), record(2)]);
        const savedFile = "File saved to '/run/user/1000/clip-daemon/edits/clipboard-45423e6b-447c-4813-8366-3a5e7c545b95.png'.";
        const entries = [Object.assign(preview(100), {summary: "Chat", body: savedFile, closed_unix_ms: 100001}),
            Object.assign(preview(3), {summary: "Unique subject", body: "<b>Plain message</b> ".repeat(12)}),
            Object.assign(preview(2), {summary: "", body: "Copied to clipboard."})];
        controller.catalog.acceptDetail(Object.assign({}, controller.catalog.detail, {overview: entries, entries: entries}));
        projectTimeline(controller, entries);
        projectApps(controller, [{key: "Chat", count: 3, total_count: 3, latest: entries[0]}]);
        for (const tab of ["notifications"]) {
            controller.setDetailsTab(tab);
            verify(waitForRendering(content));
            const label = findChild(content, "notificationAppLabel-Chat");
            verify(label !== null);
            compare(label.title, savedFile, "the latest notification's content is primary, without a repeated app-name heading");
            verify(!label.subtitle.includes(savedFile), "content must not repeat on the metadata line");
            verify(label.subtitle.endsWith(" · Chat · 3 notifications"));
            verify(label.titlePixelSize > label.subtitlePixelSize);
            verify(label.titleColor !== label.subtitleColor);
            const first = findChild(content, "notificationPreview-100:100000");
            const next = findChild(content, "notificationPreview-3:3000");
            const title = findChild(content, "notificationPreviewTitle-3:3000");
            const body = findChild(content, "notificationPreviewBody-3:3000");
            const meta = findChild(content, "notificationPreviewMeta-3:3000");
            verify(!findChild(content, "notificationPreviewTitle-100:100000").visible, "do not promote a file path into a bold headline");
            compare(findChild(content, "notificationPreviewBody-100:100000").text, savedFile);
            verify(!findChild(content, "notificationPreviewTitle-2:2000").visible);
            verify(title.font.pixelSize > body.font.pixelSize && body.font.pixelSize > meta.font.pixelSize);
            verify(title.font.weight > body.font.weight);
            verify(body.color !== meta.color);
            compare(body.textFormat, Text.PlainText);
            verify(body.lineCount <= 2 && body.height > 0);
            verify(title.mapToItem(next, 0, 0).x >= 12, "card padding separates content from its edge");
            verify(next.mapToItem(content, 0, 0).y - first.mapToItem(content, 0, 0).y - first.height > 0, "notifications have separate surfaces and breathing room");
            verify(first.color.a > 0);
            verify(!content.detailsNavigation.targets.includes(first));
            verify(findChild(content, "notificationCard-100:100000:read") === null, "previews have no Message navigation arrow");
            const deletion = findChild(content, "notificationCard-100:100000:delete");
            verify(deletion !== null);
            compare(deletion.border.width, 0);
            verify(!content.detailsNavigation.targets.includes(deletion));
            mouseClick(first, 6, 6);
            compare(controller.detailsTab, "notifications", "cards remain passive");
        }
        content.destroy(); wait(0);
    }
    function test_appRowUsesLatestContentThenTimeAppAndTotalCount() {
        const controller = makeController(makeState());
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller});
        const latest = Object.assign(preview(100, "Chat"), {created_unix_ms: controller.nowMs - 300000, summary: "Build finished", body: "All tests passed."});
        projectApps(controller, [{key: "Chat", count: 2, total_count: 47, latest: latest}]);
        tryVerify(() => findChild(content, "notificationAppLabel-Chat") !== null);
        const label = findChild(content, "notificationAppLabel-Chat");
        compare(label.title, "Build finished · All tests passed.");
        compare(label.subtitle, "5m · Chat · 47 notifications", "show total notifications, not just the filtered count");
        compare(findChild(content, "notificationAppRow-Chat").accessibleName, label.title + " · " + label.subtitle + " · 2 matching");
        verify(findChild(content, "notificationSilence-Chat") !== null);
        verify(findChild(content, "notificationDelete-Chat") !== null);
        for (const data of [
            {summary: "Chat", body: "Copied to clipboard.", expected: "Copied to clipboard."},
            {summary: "Done", body: "Done", expected: "Done"},
            {summary: "", body: "", expected: "Notification"}
        ]) {
            projectApps(controller, [{key: "Chat", count: 2, total_count: 47, latest: Object.assign({}, latest, {summary: data.summary, body: data.body})}]);
            tryCompare(label, "title", data.expected);
            compare(label.subtitle, "5m · Chat · 47 notifications");
            compare(controller.selectedAppKey, "Chat", "preview updates do not change row identity or command scope");
        }
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
    function test_arrivalsRetainAppControlDraftAndDoNotSave() {
        const state = makeState();
        state.applySummary({available: true, backend: "native", app_policies: {}});
        const controller = makeController(state);
        controller.uiActive = true; controller.openDetails();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller});
        tryVerify(() => findChild(content, "notificationTimelineList") !== null);
        controller.setDetailsTab("controls");
        tryVerify(() => findChild(content, "notificationAppDelivery") !== null);
        const field = findChild(content, "notificationAppDelivery");
        content.detailsNavigation.focusContent(true);
        tryCompare(content.detailsNavigation, "currentTarget", field);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Space);
        tryCompare(field.popup, "visible", true);
        keyClick(Qt.Key_Down);
        const draft = field.value;
        const before = testCase.calls.filter(call => call.method === "notifications.setAppPolicy").length;
        projectApps(controller, [app(101, "Chat", 500)]);
        wait(30);
        compare(findChild(content, "notificationAppDelivery"), field);
        verify(field.popup.visible);
        compare(field.value, draft);
        verify(!state.appPolicy("Chat").silent);
        keyClick(Qt.Key_Escape);
        compare(field.value, "normal");
        compare(testCase.calls.filter(call => call.method === "notifications.setAppPolicy").length, before);
        content.destroy(); wait(0);
    }
    function test_twoIconTabsHaveNoMessageRouteOrSenderCommands() {
        const state = makeState();
        state.notificationActive = {notifications: [Object.assign(notification(100), {actions: [{key: "default", label: "Open"}, {key: "inline-reply", label: "Reply"}]})]};
        const controller = makeController(state);
        controller.uiActive = true;
        const content = createTemporaryObject(contentComponent, controller, {controller: controller});
        projectTimeline(controller, [preview(100), preview(3)]);
        const senderCalls = () => testCase.calls.filter(call => ["notifications.invokeAction", "notifications.reply"].includes(call.method)).length;
        const appReads = () => testCase.calls.filter(call => call.method === "notifications.queryCenter" && call.params.view === "app").length;
        const before = senderCalls(), beforeReads = appReads();
        content.listItem.focusList(); keyClick(Qt.Key_Return);
        tryCompare(controller, "detailsTab", "notifications");
        tryVerify(() => findChild(content, "notificationPreview-100:100000") !== null);
        compare(controller.tabs.map(tab => tab.value), ["notifications", "controls"]);
        verify(controller.tabs.every(tab => !!tab.icon && !!tab.label), "icon-only tabs retain accessible labels");
        verify(!findChild(content, "notificationCard-100:100000:read"));
        for (const tab of ["notifications", "controls", "notifications"]) {
            tryCompare(controller, "detailsTab", tab);
            keyClick(Qt.Key_O, Qt.AltModifier); keyClick(Qt.Key_R, Qt.AltModifier);
            verify(!findChild(content, "detailAction:open"));
            verify(!findChild(content, "notificationReplyInput"));
            keyClick(Qt.Key_Tab, Qt.ControlModifier);
        }
        controller.setDetailsTab("message");
        compare(controller.detailsTab, "controls", "removed tabs cannot be requested programmatically");
        wait(180);
        compare(senderCalls(), before);
        compare(appReads(), beforeReads, "the removed Message page must not start a background detail reader");
        content.destroy(); wait(0);
    }
    function test_dateHistoryUsesSharedScrollingAndKeepsAppListFixed() {
        const controller = makeController(makeState());
        projectApps(controller, [app(100, "Chat", 500), app(1, "Mail", 1)]);
        controller.uiActive = true; controller.primarySelected();
        const content = createTemporaryObject(contentComponent, controller, {controller: controller, width: 1000, height: 600});
        wait(150);
        projectTimeline(controller, Array.from({length: 100}, (_, i) => preview(1000 - i)));
        verify(!findChild(content, "notificationPage"), "transport windows do not create page fields");
        const list = findChild(content, "notificationTimelineList");
        tryCompare(list, "count", 101);
        tryCompare(controller, "detailsExpansionProgress", 1);
        wait(50);
        content.listItem.focusList(); keyClick(Qt.Key_Tab);
        const beforeScroll = list.contentY - list.originY;
        keyClick(Qt.Key_PageDown);
        tryVerify(() => list.contentY - list.originY > beforeScroll, 1000, "shared non-highlighted scrolling fallback handles PageDown relative to ListView's origin");
        const rendered = descendants(list.contentItem).filter(item => String(item.objectName || "").startsWith("notificationPreview-")).length;
        verify(rendered < 25, "virtualization does not instantiate the entire date");
        keyClick(Qt.Key_Tab, Qt.ControlModifier);
        tryCompare(controller, "detailsTab", "controls");
        verify(findChild(content, "notificationAppDelivery") !== null);
        compare(controller.notificationModel.count, 2);
        content.listItem.focusList(); keyClick(Qt.Key_Down);
        compare(controller.selectedAppKey, "Mail");
        verify(controller.detailsOpen);
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
        controller.catalog.selectedKey = "100:100000";
        projectDetail(controller, [record(100)], 2);
        verify(controller.catalog.detail.selected !== null);
        catalog.acceptDetail(Object.assign({}, catalog.detail, {selected: record(1)}));
        verify(catalog.detailError.length > 0);
        controller.catalog.selectedKey = "1:1000";
        catalog.acceptDetail(Object.assign({}, catalog.detail, {selected: null}));
        compare(controller.catalog.selectedKey, "1:1000", "missing records never retarget a native lookup");
        verify(controller.catalog.detail.selected === null);
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
        // The visible-window refresh test covers continuation read failure.
        return [{tag: "epoch"}];
    }
    function test_abandonedRefreshNeverPublishesPartialPages(data) {
        const controller = startCenter(), catalog = controller.catalog;
        const callsBefore = testCase.calls.length;
        const visible = JSON.stringify(catalog.apps);
        finishApps(controller, stagedPage());
        const continuation = appPage([app(199, "Second")], "", 1, null, 2);
        continuation.epoch = "after-restart";
        finishApps(controller, continuation);
        compare(JSON.stringify(catalog.apps), visible);
        compare(catalog.staging.length, 0);
        verify(!catalog.rootBusy);
        compare(testCase.calls.length - callsBefore, 1, "only the initial continuation, none after abandonment");
        verify(testCase.calls.slice(callsBefore).every(call => call.method === "notifications.queryCenter"));
    }
    function test_rejectInvalidCenterPages_data() {
        return [
            {tag: "missing-page", patch: null},
            {tag: "invalid-id", patch: {apps: [app(4294967296)]}}
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
        return [{tag: "wrong-record-app", patch: {entries: [preview(100, "Other")]}}];
    }
    function test_detailValidationKeepsLastCoherentRecord(data) {
        const controller = makeController(makeState());
        controller.catalog.selectedKey = "100:100000"; projectDetail(controller, [record(100)]);
        const before = JSON.stringify(controller.catalog.detail);
        controller.catalog.acceptDetail(Object.assign({}, controller.catalog.detail, data.patch));
        compare(JSON.stringify(controller.catalog.detail), before);
        verify(controller.catalog.detailError.length > 0);
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
