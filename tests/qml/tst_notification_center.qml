import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "NotificationCenter"
    width: 1100; height: 680; visible: true; when: windowShown
    Component { id: stateFactory; Activity.NotificationState {} }
    Component { id: controllerFactory; Activity.NotificationController {} }
    Component { id: contentFactory; Activity.NotificationContent {} }
    function init() { failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop|Cannot assign).*/); calls = []; clientReady = true; }
    function preview(id, app) { return {id: id, created_unix_ms: id * 1000, app_key: app, app_name: app, app_icon: "", summary: "Message " + id, body: "Body"}; }
    function make() {
        const state = createTemporaryObject(stateFactory, tests, {uiActive: true});
        state.applySummary({available: true, backend: "native", history_revision: 1, app_policies: {}});
        const controller = createTemporaryObject(controllerFactory, state, {notificationState: state, uiActive: true, width: 1100, height: 650});
        controller.catalog.apps = ["named:Chat", "named:Mail"].map((key, i) => ({key: key, count: 3, total_count: 3, latest: preview(100 - i, key)}));
        controller.rebuildRecords();
        const content = createTemporaryObject(contentFactory, controller, {controller: controller, width: 1100, height: 650});
        verify(content !== null);
        content.listItem.focusList();
        return {state: state, controller: controller, content: content};
    }
    function request(state, prefix) { return Object.keys(state.backend.requests).find(id => id.startsWith(prefix + "-")); }
    function test_globalSettingsUseDeferredSliderTransactionsAndAcknowledgements() {
        const {state, controller, content} = make();
        const summary = {available: true, backend: "native", history_revision: 2, app_policies: {}, settings: {countdown: true, code_expiry_seconds: 60, history_days: 30}};
        state.applySummary(summary);
        controller.openSettings();
        tryVerify(() => content.detailsNavigation.contentReady);
        const days = findChild(content, "notificationHistoryDays");
        verify(days);
        const slider = findChild(days, "labeledValueSliderInput");
        content.detailsNavigation.focusContent(true);
        for (let i = 0; i < 12 && content.detailsNavigation.currentTarget !== days; ++i) keyClick(Qt.Key_Tab);
        compare(content.detailsNavigation.currentTarget, days);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Left);
        compare(calls.filter(c => c.method === "notifications.setSettings").length, 0);
        keyClick(Qt.Key_Escape);
        compare(slider.value, 30);
        keyClick(Qt.Key_Return); keyClick(Qt.Key_Left); keyClick(Qt.Key_Tab);
        const saved = calls.filter(c => c.method === "notifications.setSettings");
        compare(saved.length, 1);
        compare(saved[0].params, {history_days: 29});
        compare(state.settings.history_days, 30, "draft is not an acknowledgement");
        verify(state.settingsPending);
        state.backend.finish(request(state, "settings"), {notifications: Object.assign({}, summary, {history_revision: 3, settings: {countdown: true, code_expiry_seconds: 60, history_days: 29}})}, "", "");
        compare(state.settings.history_days, 29);
        verify(!state.settingsPending);
        state.setSettings({countdown: false});
        state.backend.finish(request(state, "settings"), {}, "Disk full", "");
        compare(state.settings.countdown, true);
        compare(state.settingsError, "Disk full");
        content.destroy();
    }
    function test_settingsReplyOwnershipAndEventFence() {
        const {state, controller, content} = make();
        const summary = {available: true, backend: "native", history_revision: 2, settings: {countdown: true, code_expiry_seconds: 60, history_days: 30}};
        state.applySummary(summary);
        controller.openSettings();
        tryVerify(() => content.detailsNavigation.contentReady);
        const toggle = findChild(content, "notificationCountdownSetting");
        content.detailsNavigation.focusContent(true);
        for (let i = 0; i < 12 && content.detailsNavigation.currentTarget !== toggle; ++i) keyClick(Qt.Key_Tab);
        compare(content.detailsNavigation.currentTarget, toggle);
        keyClick(Qt.Key_Return);
        const first = request(state, "settings");
        verify(!!first);
        state.lastError = "Independent operation error";
        state.backend.finish(first, {notifications: {settings: {countdown: false, history_days: 31, code_expiry_seconds: 60}}}, "", "");
        compare(state.settingsError, "Invalid notification settings acknowledgement");
        compare(state.settings.countdown, true);
        keyClick(Qt.Key_Return);
        const second = request(state, "settings");
        verify(!!second && second !== first);
        state.backend.finish(first, {}, "Duplicate failure", "");
        verify(state.settingsPending);
        compare(state.settingsError, "");
        state.queueEvent(true, Object.assign({}, summary, {history_revision: 3, settings: {countdown: true, code_expiry_seconds: 60, history_days: 20}}));
        state.backend.finish(second, {notifications: Object.assign({}, summary, {settings: {countdown: false, code_expiry_seconds: 60, history_days: 30}})}, "", "");
        verify(!state.settingsPending);
        compare(state.settings.history_days, 20);
        compare(state.settings.countdown, true, "Queued observations precede an old acknowledgement");
        compare(state.lastError, "Independent operation error");
        content.destroy();
    }
    function test_deleteFromUnselectedRowConfirmsNativeScopeAndNeverReplays() {
        const {state, controller, content} = make();
        tryVerify(() => findChild(content, "notificationDelete-named:Mail") !== null);
        const button = findChild(content, "notificationDelete-named:Mail");
        compare(button.border.width, 0);
        compare(findChild(content, "notificationSilence-named:Mail").border.width, 0);
        mouseClick(button);
        compare(controller.selectedAppKey, "named:Chat", "row deletion does not select an implicit target");
        const prepare = calls.filter(c => c.method === "notifications.prepareDelete").pop();
        compare(prepare.params, {app_key: "named:Mail", selected: null});
        verify(state.deletePreparing);
        const challenge = {token: "owned", count: 300, app_key: "named:Mail", expires_unix_ms: Date.now() + 60000};
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: challenge}, "", "");
        verify(controller.navigationBlocked);
        verify(waitForRendering(findChild(content, "notificationDeleteConfirmation")));
        wait(20);
        keyClick(Qt.Key_Escape);
        tryCompare(state, "deleteConfirmation", null);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "owned", cancel: true});
        state.lastError = "Independent operation error";
        state.backend.finish(request(state, "delete"), {cancelled: true}, "", "");
        compare(state.lastError, "Independent operation error", "Cancellation never falls through to generic success");
        content.listItem.focusList(); keyClick(Qt.Key_D, Qt.AltModifier);
        state.backend.finish(request(state, "prepare-delete"), {delete_confirmation: Object.assign({}, challenge, {token: "second", app_key: "named:Chat"})}, "", "");
        const modal = findChild(content, "notificationDeleteConfirmation");
        tryCompare(findChild(modal, "detailAction:reject"), "activeFocus", true);
        verify(modal.compactPresentation && !modal.actionSummaryVisible);
        verify(!findChild(modal, "modalDetail").visible);
        keyClick(Qt.Key_Tab);
        verify(findChild(modal, "detailAction:accept").activeFocus);
        keyClick(Qt.Key_Return);
        verify(state.deletePending);
        compare(calls.filter(c => c.method === "notifications.delete").pop().params, {token: "second", cancel: false});
        const before = calls.length; state.confirmDelete(); compare(calls.length, before);
        state.backend.finish(request(state, "delete"), {}, "Connection lost; refresh before retrying", "");
        verify(!state.deletePending); verify(state.lastError.length > 0);
        compare(controller.visibleApps.length, 2, "failure cannot optimistically remove notifications");
        content.destroy();
    }
    function timelinePage(offset, ids, next) {
        return {view: "timeline", epoch: "epoch", revision: "1", query: "", app_key: "named:Chat", date: "older", period_day: "2026-10-08", recent: [1000,999,998].map(id => preview(id, "named:Chat")), dates: ["today", "week", "month", "older"].map(key => ({key: key, count: key === "older" ? 40 : 0})), count: 40, total_rows: 40, offset: offset, next_offset: next, anchor_reached: true,
            entries: ids.map(id => ({key: id + ":" + id * 1000, preview: preview(id, "named:Chat"), members: [{id: id, created: id * 1000}]}))};
    }
    function test_previewCommandsKeepStackAndRecordIdentityInTheOwner() {
        const {state, controller, content} = make();
        keyClick(Qt.Key_Right);
        tryVerify(() => content.detailsNavigation.contentReady);
        const timeline = controller.timeline;
        timeline.requestedDate = "older"; timeline.collapsed = false;
        const page = timelinePage(0, [100], null);
        page.recent = [];
        page.count = 2; page.total_rows = 1;
        page.dates[3].count = 2;
        page.entries[0].members.push({id: 99, created: 99000});
        timeline.receive({view: "timeline", generation: timeline.generation, appKey: timeline.appKey,
            query: timeline.query, date: "older", grouping: timeline.grouping, offset: 0, replacing: true,
            revision: state.observedHistoryRevision}, page, "", "");
        compare(timeline.error, "");
        tryVerify(() => findChild(content, "notificationCard-100:100000:expand") !== null);
        keyClick(Qt.Key_Tab);
        compare(content.detailsNavigation.highlightedControl, null, "previews add no editable fields");
        const expand = findChild(content, "notificationCard-100:100000:expand");
        mouseClick(expand);
        compare(timeline.expandedStacks["100:100000"], true);
        compare(controller.selectedAppKey, "named:Chat");
        const list = findChild(content, "notificationTimelineList");
        list.positionViewAtIndex(3, ListView.Contain);
        tryVerify(() => findChild(content, "notificationCard-member:99:99000:delete") !== null);
        wait(20);
        const remove = findChild(content, "notificationCard-member:99:99000:delete");
        mouseClick(remove);
        const prepares = calls.filter(call => call.method === "notifications.prepareDelete");
        compare(prepares.length, 1);
        compare(prepares[0].params, {app_key: "named:Chat", selected: {id: 99, created: 99000}});
        verify(!remove.enabled, "pending consent disables repeat deletion");
        mouseClick(remove);
        compare(calls.filter(call => call.method === "notifications.prepareDelete").length, 1);
        compare(controller.selectedAppKey, "named:Chat");
        state.cancelDelete();
        content.destroy();
    }
    function test_timelineAtomicWindowsRejectDuplicateAndStaleReplies() {
        const {state, controller, content} = make();
        controller.openDetails();
        const timeline = controller.timeline;
        timeline.requestedDate = "older"; timeline.collapsed = false;
        const context = offset => ({view: "timeline", generation: timeline.generation, appKey: timeline.appKey, query: timeline.query, date: timeline.requestedDate, grouping: timeline.grouping, offset: offset, replacing: offset === 0, revision: state.observedHistoryRevision});
        const ids = Array.from({length: 20}, (_, i) => 100 - i);
        timeline.receive(context(0), timelinePage(0, ids, 20), "", "");
        compare(timeline.entries.length, 20);
        const good = JSON.stringify(timeline.entries);
        timeline.receive(context(20), timelinePage(20, ids, null), "", "");
        verify(timeline.error.length > 0); compare(JSON.stringify(timeline.entries), good);
        timeline.error = "";
        const midnight = timelinePage(20, ids.map(id => id - 20), null);
        midnight.period_day = "2026-10-09";
        timeline.receive(context(20), midnight, "", "");
        compare(JSON.stringify(timeline.entries), good); verify(timeline.dirty, "calendar snapshots cannot be mixed");
        const duplicateRecent = timelinePage(0, [1000].concat(ids.slice(1)), 20);
        timeline.receive(context(0), duplicateRecent, "", "");
        verify(timeline.error.length > 0, "recent previews cannot duplicate a period record");
        compare(JSON.stringify(timeline.entries), good);
        timeline.error = "";
        const stale = context(20);
        state.applySummary({available: true, history_revision: 2, app_policies: {}});
        timeline.receive(stale, timelinePage(20, ids.map(id => id - 20), null), "", "");
        compare(JSON.stringify(timeline.entries), good); verify(timeline.dirty);
        const generation = timeline.generation;
        timeline.requestedDate = "week";
        timeline.receive(Object.assign({}, stale, {generation: generation}), timelinePage(20, ids, null), "", "");
        compare(timeline.entries.length, 0, "superseded dates cannot repopulate the viewport");
        content.destroy();
    }
}
