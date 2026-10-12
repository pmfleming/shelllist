pragma ComponentBehavior: Bound
import QtQuick
import Shelllist.Io as Io
import Shelllist.Bar as Bar
import Shelllist.Battery as Battery
import Shelllist.Activity as Activity
import "../../bar/BarApi.js" as Api

DaemonTestCase {
    id: tests
    name: "BarReadContract"
    when: windowShown
    property var loadedFixture: null

    Component { id: barFactory; Bar.BarController { surfaceRegistry: null } }
    Component { id: batteryFactory; Battery.BatteryController { uiActive: true } }
    Component { id: notificationsFactory; Activity.NotificationState { resident: true } }
    Component { id: motionFactory; Io.CompositorMotion { active: true } }
    Component { id: areaFactory; Io.HyprlandWorkAreaClient { active: true; monitorName: "eDP-1" } }

    function fixture() {
        if (!loadedFixture) {
            const request = new XMLHttpRequest();
            request.open("GET", Qt.resolvedUrl("fixtures/bar-reads.json"), false);
            request.send();
            loadedFixture = JSON.parse(request.responseText);
        }
        return loadedFixture;
    }
    function init() {
        calls = [];
        clientReady = true;
        failOnWarning(/.*(?:TypeError|ReferenceError|Binding loop).*/);
    }
    function requests(backend) {
        return calls.filter(call => call.route.consumerId === backend.sharedConsumerId);
    }
    function lastRead(backend) {
        const reads = requests(backend).filter(call => call.method === Api.methods.snapshot);
        verify(reads.length > 0, "Missing bar.snapshot");
        return reads[reads.length - 1];
    }
    function reply(call) {
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, fixture().snapshot, "", call.route);
    }
    function event(call, value) {
        const route = Object.assign({}, call.route, {kind: "base-subscription", localId: "session-subscribe"});
        Io.DaemonSessions.sessions["bar-daemon"].client.eventReceived(value, route);
    }
    function makeBar() {
        const controller = createTemporaryObject(barFactory, tests);
        verify(controller !== null);
        reply(lastRead(controller.backend));
        verify(!controller.backend.snapshotLoading);
        compare(controller.backend.snapshotError, "");
        return controller;
    }
    function verifySnapshot(controller) {
        const snapshot = fixture().snapshot.data.snapshot;
        for (const field of Object.keys(Api.propertyByPayload))
            compare(controller[Api.propertyByPayload[field]], snapshot[field], field);
    }
    function test_snapshotUsesActualReplyEnvelope() {
        const controller = makeBar();
        verifySnapshot(controller);
        verify(!controller.osdVisible, "A snapshot must not produce change-event OSDs");
        compare(requests(controller.backend).length, 1);
    }
    function test_barStreams_data() {
        return Object.keys(Api.streams).map(property => ({tag: property, property: property, stream: Api.streams[property]}));
    }
    function test_barStreams(data) {
        const controller = makeBar();
        const call = lastRead(controller.backend);
        const before = requests(controller.backend).length;
        const others = {};
        for (const property of Object.keys(Api.streams))
            if (property !== data.property)
                others[property] = JSON.stringify(controller[property]);
        event(call, fixture().subscribed[data.stream]);
        compare(controller[data.property], fixture().subscribed[data.stream].data);
        verify(!controller.osdVisible, "Subscribed is initial state, not a user change");
        for (const property of Object.keys(others))
            compare(JSON.stringify(controller[property]), others[property], "Unrelated domain " + property);
        event(call, fixture().changed[data.stream]);
        compare(controller[data.property], fixture().changed[data.stream].data);
        verifySnapshot(controller);
        compare(requests(controller.backend).length, before, "Push delivery cannot be hidden by snapshot recovery");
    }
    function test_laggedEventsRecoverReadOnly_data() { return test_barStreams_data(); }
    function test_laggedEventsRecoverReadOnly(data) {
        const controller = makeBar();
        const call = lastRead(controller.backend);
        const before = requests(controller.backend).length;
        event(call, fixture().lagged[data.stream]);
        compare(requests(controller.backend).length, before + 1);
        verifySnapshot(controller); // Never apply {missed: ...} as domain state.
        reply(lastRead(controller.backend));
        verifySnapshot(controller);
        verify(requests(controller.backend).every(call => call.method === Api.methods.snapshot), "Recovery never sends effects");
    }
    function test_invalidMetadataDoesNotReachConsumer() {
        const controller = makeBar();
        const call = lastRead(controller.backend);
        const value = fixture().subscribed[Api.streams.audio];
        for (const patch of [{protocol: "foreign-api"}, {version: Api.version + 1}, {stream: ""}, {event: ""}]) {
            event(call, Object.assign({}, value, patch));
            verifySnapshot(controller);
        }
        event(call, value);
        compare(controller.audio, value.data, "Valid data still routes after rejected envelopes");
        compare(requests(controller.backend).length, 1);
    }
    function test_projections_data() {
        return [{tag: "workarea", projection: "workarea"}, {tag: "compositor", projection: "compositor"}];
    }
    function test_projections(data) {
        const area = data.projection === "workarea";
        const client = createTemporaryObject(area ? areaFactory : motionFactory, tests);
        verify(client !== null);
        const backend = findChild(client, area ? "workAreaBackend" : "compositorMotionBackend");
        verify(backend !== null);
        const call = lastRead(backend);
        const stream = data.projection + ".changed";
        event(call, fixture().subscribed[stream]);
        if (area) {
            compare(client.snapshot.available, false);
            compare(client.insets, null);
        } else {
            verify(!client.available && !client.reduced);
        }
        event(call, fixture().changed[stream]);
        if (area) {
            compare(client.insets, fixture().changed[stream].data.monitors["eDP-1"]);
            verify(client.ready);
        } else {
            verify(client.available && client.reduced);
            compare(client.revision, fixture().changed[stream].data.revision);
        }
        compare(requests(backend).length, 1, "A push does not require polling");
        reply(call);
        event(call, fixture().lagged[stream]);
        compare(requests(backend).length, 2);
        reply(lastRead(backend));
        if (area)
            compare(client.snapshot, fixture().snapshot.data.snapshot.workarea);
        else
            verify(client.available && client.reduced);
        verify(requests(backend).every(call => call.method === Api.methods.snapshot));
    }
    function test_batteryConsumerIncludesSleepPolicy() {
        const controller = createTemporaryObject(batteryFactory, tests);
        verify(controller !== null);
        const call = lastRead(controller.backend);
        reply(call);
        const snapshot = fixture().snapshot.data.snapshot;
        compare(controller.battery, snapshot.battery);
        compare(controller.powerProfile, snapshot.power_profile);
        compare(controller.powerSuspend, snapshot.power_sleep);
        compare(controller.suspendPolicyState, snapshot.sleep_policy);
        const before = requests(controller.backend).length;
        event(call, fixture().subscribed["sleep-policy.changed"]);
        compare(controller.suspendPolicyState, fixture().subscribed["sleep-policy.changed"].data);
        event(call, fixture().changed["sleep-policy.changed"]);
        compare(controller.suspendPolicyState, snapshot.sleep_policy);
        compare(requests(controller.backend).length, before, "Sleep-policy pushes do not need polling");
        // Battery independently loads history when the first snapshot arrives.
        verify(requests(controller.backend).every(call => [Api.methods.snapshot, "battery.history"].includes(call.method)));
    }
    function test_residentNotifications_data() {
        return [{tag: "snapshot", pushes: false}, {tag: "events", pushes: true}];
    }
    function test_residentNotifications(data) {
        const store = createTemporaryObject(notificationsFactory, tests);
        verify(store !== null);
        const call = lastRead(store.backend);
        if (data.pushes) {
            for (const stream of [Api.streams.notifications, Api.streams.notificationActive]) {
                event(call, fixture().subscribed[stream]);
                event(call, fixture().changed[stream]);
            }
            tryVerify(() => store.notifications.available && store.notificationActive.available);
        } else {
            reply(call);
        }
        compare(store.notifications, fixture().snapshot.data.snapshot.notifications);
        compare(store.notificationActive, fixture().snapshot.data.snapshot.notification_active);
        compare(store.activeRecords.length, 1);
        compare(store.activeRecords[0].summary, "Planning");
        compare(requests(store.backend).length, 1);
    }
}
