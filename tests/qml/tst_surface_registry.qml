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

    function test_audioMediaAndTrayHaveIndependentLazyControllers(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        for (const kind of ["audio", "media", "tray"]) {
            compare(registry.controllerFor(kind), null);
            verify(registry.select(kind));
            tryVerify(() => registry.controllerFor(kind) !== null);
            compare(registry.controllerFor(kind).kind, kind);
            verify(registry.controllerFor(kind).viewMemory !== null);
        }
        verify(registry.controllerFor("audio") !== registry.controllerFor("media"));
    }

    function test_requestsQueuedBeforeLoadApplyOnceTheControllerExists(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        compare(registry.bundleFor("time-weather"), null, "surfaces load lazily");
        registry.requestTimeWeatherTab("weather");
        tryVerify(function () {
            return registry.controllerFor("time-weather") !== null;
        });
        compare(registry.controllerFor("time-weather").detailsTab, "weather");

        registry.openNotifications("Mail", "history", "activity");
        tryVerify(function () {
            return registry.notificationController !== null;
        });
        compare(registry.notificationController.tab, "history");
        compare(registry.notificationController.returnSurface, "activity");
    }

}
