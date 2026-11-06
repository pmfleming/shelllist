import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io
import "../../bar/BarDaemonRouting.js" as Routing
import "../../bar/BarApi.js" as BarApi

DaemonTestCase {
    id: tests
    name: "BarSeparation"
    when: windowShown
    Component {
        id: factory
        Bar.BarController { surfaceRegistry: null }
    }
    function test_notificationRequestsUseTheirOwnSession() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        verify(Io.DaemonSessions.sessions["bar-daemon"] !== undefined);
        verify(Io.DaemonSessions.sessions["bar-notification-daemon"] !== undefined);
        const session = Io.DaemonSessions.sessions["bar-notification-daemon"];
        Object.values(session.consumers).forEach(consumer => {
            Array.from(consumer.backend.streams).forEach(stream => verify(stream.startsWith("notifications.")));
        });
        const before = calls.length;
        verify(controller.backend.toggleDnd());
        compare(calls.length, before + 1);
        verify(!!Io.DaemonSessions.sessions["bar-notification-daemon"].consumers[calls[calls.length - 1].route.consumerId]);
    }
    function test_powerRequestsUseTheirOwnSession() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        verify(controller.backend.setPowerProfile("balanced"));
        const last = calls[calls.length - 1];
        compare(last.method, "powerProfile.set");
        verify(!!Io.DaemonSessions.sessions["bar-power-daemon"].consumers[last.route.consumerId]);
        verify(controller.backend.powerRequestRunning);
    }

    function test_workspaceRequestsUseTheirOwnSession() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        verify(controller.backend.focusWorkspace(2));
        const last = calls[calls.length - 1];
        compare(last.method, "workspace.focus");
        verify(!!Io.DaemonSessions.sessions["bar-compositor-daemon"].consumers[last.route.consumerId]);
    }

    function test_everySubscriptionTargetsItsOwner() {
        const controller = createTemporaryObject(factory, tests);
        verify(controller !== null);
        Routing.daemons.forEach(daemon => {
            const session = Io.DaemonSessions.sessions[daemon];
            verify(session !== undefined);
            Object.values(session.consumers).forEach(consumer => {
                Array.from(consumer.backend.streams).forEach(stream => compare(Routing.daemonForStream(stream), daemon));
            });
        });
    }
    function test_powerLossLeavesAudioSubscriptionActive() {
        const controller = createTemporaryObject(factory, tests);
        seedBarDaemon("bar-power-daemon", null);
        const bar = Io.DaemonSessions.sessions["bar-daemon"];
        const client = bar.client;
        const subscriptions = client.subscriptions.length;
        Io.DaemonSessions.sessions["bar-power-daemon"].client.transportFailed("power exited");
        compare(Io.DaemonSessions.sessions["bar-daemon"].client, client);
        compare(client.subscriptions.length, subscriptions);
        verify(controller.backend.ready);
        compare(controller.battery.available, false);
    }

    function test_eachOwnerLossInvalidatesItsState_data() {
        return Routing.daemons.filter(daemon => daemon !== "bar-daemon").map(daemon => ({tag: daemon, daemon: daemon}));
    }
    function test_eachOwnerLossInvalidatesItsState(data) {
        const controller = createTemporaryObject(factory, tests);
        Routing.daemons.forEach(daemon => {
            const patches = {};
            Object.values(Io.DaemonSessions.sessions[daemon].consumers).forEach(consumer => {
                Array.from(consumer.backend.streams).forEach(stream => patches[stream] = {available: true});
            });
            seedBarDaemon(daemon, patches);
        });
        Io.DaemonSessions.sessions[data.daemon].client.transportFailed("owner unavailable");
        Routing.daemons.filter(daemon => daemon !== "bar-daemon").forEach(daemon => {
            Routing.streamsByDaemon[daemon].forEach(stream => {
                const property = BarApi.propertyByStream[stream];
                if (property) compare(controller[property].available, daemon !== data.daemon, daemon + ":" + property);
            });
        });
        verify(controller.backend.toggleMuted());
        const call = calls[calls.length - 1];
        Io.DaemonSessions.sessions["bar-daemon"].client.response(call.id, {protocol:"bar-api", version:2, ok:true, data:{}}, "", call.route);
        compare(controller.backend.operationError, "");
        Routing.streamsByDaemon[data.daemon].forEach(stream => {
            const property = BarApi.propertyByStream[stream];
            if (property) {
                compare(controller[property].available, false);
                compare(controller[property].error, "owner unavailable");
            }
        });
    }

}
