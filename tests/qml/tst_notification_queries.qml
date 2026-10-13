pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Activity as Activity

DaemonTestCase {
    id: tests
    name: "NotificationQueryContract"
    when: windowShown
    property var loaded: null
    Component { id: stateFactory; Activity.NotificationState { uiActive: true } }
    Component { id: catalogFactory; Activity.NotificationCatalog {} }
    Component { id: timelineFactory; Activity.NotificationTimeline {} }
    Component { id: controllerFactory; Activity.NotificationController { uiActive: true } }
    function fixture() {
        if (!loaded) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-notification-queries.json"), false);
            request.send(); loaded = JSON.parse(request.responseText);
        }
        return loaded;
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function init() { calls = []; clientReady = true; failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/); }
    function requests(s) { return calls.filter(call => call.route.consumerId === s.backend.sharedConsumerId); }
    function centerReads(s) { return requests(s).filter(call => call.method === "notifications.queryCenter"); }
    function lastCall(s, method) {
        const found = requests(s).filter(call => call.method === method);
        verify(found.length > 0, "Missing " + method); return found[found.length - 1];
    }
    function reply(call, envelope, error) { Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, clone(envelope), error || "", call.route); }
    function make() {
        const s = createTemporaryObject(stateFactory, tests); verify(s !== null);
        reply(lastCall(s, "bar.snapshot"), fixture().snapshot);
        verify(s.notifications.available); return s;
    }
    function catalog(s) {
        const c = createTemporaryObject(catalogFactory, s, {store:s}); verify(c !== null);
        c.active = true; c.reloadApps(); return c;
    }
    function respond(s, key, exactParams) {
        const example = fixture().cases[key]; const call = lastCall(s, example.method);
        if (exactParams) compare(call.params, example.params);
        reply(call, example.success); verify(!s.backend.isPending(call.route.localId)); return call;
    }
    function assertReadsOnly(s) {
        verify(requests(s).every(call => ["bar.snapshot", "notifications.queryCenter"].includes(call.method)));
    }
    function test_appWindowsAreNativeOrderedAndDisjoint() {
        const s = make(); const c = catalog(s); const before = clone(s.notifications);
        respond(s, "apps", true);
        compare(c.apps, fixture().cases.apps.success.data.notification_center.apps); verify(c.hasMore);
        c.loadMore(); respond(s, "apps-next", true);
        compare(c.apps.length, 52); compare(new Set(c.apps.map(a => a.key)).size, 52); verify(!c.hasMore);
        compare(s.notifications, before); assertReadsOnly(s);
    }
    function test_groupResolutionStagesPagesUntilAnchorArrives() {
        const s = make();
        const c = createTemporaryObject(controllerFactory, s, {notificationState:s}); verify(c !== null);
        c.openNotifications(fixture().cases.resolve.params.group_key, "active", "activity");
        tryVerify(() => centerReads(s).some(call => call.params.view === "app"));
        respond(s, "resolve", true);
        respond(s, "apps-anchor", true);
        compare(c.catalog.apps.length, 0, "Unpublished partial app windows cannot replace the catalog");
        verify(c.catalog.rootBusy);
        respond(s, "apps-anchor-next", true);
        tryCompare(c, "selectedAppKey", fixture().cases.resolve.success.data.notification_center.app_key);
        compare(c.catalog.apps.length, 52); assertReadsOnly(s);
    }
    function test_timelineWindowPreservesNativeStacksAndCursor() {
        const s = make(); const t = createTemporaryObject(timelineFactory, s, {store:s}); verify(t !== null);
        t.appKey = fixture().cases.timeline.params.app_key; t.requestedDate = "older"; t.active = true; t.reload();
        respond(s, "timeline", true);
        compare(t.entries.length, 20); compare(t.totalCount, 25); verify(t.hasMore);
        t.loadMore(); respond(s, "timeline-next", true);
        compare(t.entries.length, 21); verify(!t.hasMore); compare(t.entries[20].members.length, 2);
        compare(t.snapshot.period_day, "2026-01-15"); compare(t.error, ""); assertReadsOnly(s);
    }
    function test_errorsKeepPublishedCatalogWithoutReadLoops_data() {
        return ["invalid", "busy"].map(key => ({tag:key, key:key}));
    }
    function test_errorsKeepPublishedCatalogWithoutReadLoops(data) {
        const s = make(); const c = catalog(s); respond(s, "apps", true); const before = clone(c.apps);
        c.reloadApps(); const call = lastCall(s, "notifications.queryCenter");
        reply(call, fixture().errors[data.key]);
        compare(c.apps, before); compare(c.rootError, fixture().errors[data.key].error.message); verify(!c.rootBusy);
        const count = centerReads(s).length; wait(180); compare(centerReads(s).length, count);
        c.reloadApps(); respond(s, "apps", false); compare(c.rootError, ""); assertReadsOnly(s);
    }
    function test_staleContinuationRestartsReadAtRoot() {
        const s = make(); const c = catalog(s); respond(s, "apps", true);
        c.loadMore(); const continuation = lastCall(s, "notifications.queryCenter"); compare(continuation.params.offset, 50);
        reply(continuation, fixture().errors.stale);
        tryCompare(c, "rootBusy", true);
        const root = lastCall(s, "notifications.queryCenter"); compare(root.params.offset, 0); compare(root.params.epoch, null);
        reply(root, fixture().cases.apps.success); compare(c.apps.length, 50); compare(c.rootError, ""); assertReadsOnly(s);
    }
    function test_oldSearchAndOldTransportResponsesAreFenced() {
        const s = make(); const c = catalog(s); const old = lastCall(s, "notifications.queryCenter");
        c.query = "no-match"; c.reloadApps(); const current = lastCall(s, "notifications.queryCenter");
        reply(old, fixture().cases.apps.success); verify(c.rootBusy); compare(c.apps.length, 0);
        reply(current, fixture().cases.empty.success); compare(c.rootError, ""); compare(c.apps.length, 0);
        c.query = ""; c.reloadApps(); const lost = lastCall(s, "notifications.queryCenter");
        clientReady = false; Io.DaemonSessions.sessions["bar-daemon"].client.transportFailed("Connection lost"); clientReady = true;
        reply(lastCall(s, "bar.snapshot"), fixture().snapshot);
        reply(lost, fixture().cases.apps.success); compare(c.apps.length, 0);
        tryVerify(() => lastCall(s, "notifications.queryCenter").id !== lost.id);
        respond(s, "apps", false); compare(c.apps.length, 50); assertReadsOnly(s);
    }
}
