pragma ComponentBehavior: Bound

import QtQuick
import "../../shell" as Shell

DaemonTestCase {
    id: testCase
    name: "SurfaceRegistry"
    when: windowShown
    visible: true
    width: 400
    height: 400

    Component {
        id: registryComponent
        Shell.SurfaceRegistry {}
    }

    function test_requestsQueuedBeforeLoadApplyOnceTheControllerExists(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        compare(registry.bundleFor("time-weather"), null, "surfaces load lazily");
        registry.requestTimeWeatherTab("weather");
        tryVerify(function () { return registry.controllerFor("time-weather") !== null; });
        compare(registry.controllerFor("time-weather").detailsTab, "weather");

        registry.openNotifications("Mail", "history", "activity");
        tryVerify(function () { return registry.notificationController !== null; });
        compare(registry.notificationController.tab, "history");
        compare(registry.notificationController.returnSurface, "activity");
    }

    function test_selectLoadsAndExposesTheCurrentSurface(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        verify(!registry.select("unknown"));
        verify(registry.select("displays"));
        compare(registry.currentDescriptor.name, "Displays");
        tryVerify(function () { return registry.currentController !== null; });
        verify(registry.currentController === registry.displayController);
        verify(registry.wifiController !== null, "Wi-Fi stays resident for the bar");
    }
}
