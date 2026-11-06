import QtQuick
import Shelllist.Bar as Bar
import Shelllist.Io as Io

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

}
