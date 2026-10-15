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

    function test_pendingActionRunsOnceAndLatestRequestWins(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        let obsolete = 0;
        let applied = 0;
        registry.whenReady("clipboard", function () { obsolete++; });
        registry.whenReady("clipboard", function () { applied++; });
        tryCompare(registry, "currentId", "applications");
        tryVerify(() => registry.controllerFor("clipboard") !== null);
        compare(obsolete, 0);
        compare(applied, 1);
        registry.notifySurfaceReady("clipboard");
        compare(applied, 1);
    }

    function test_requestsQueuedBeforeLoadApplyOnceTheControllerExists(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        compare(registry.bundleFor("time-weather"), null, "surfaces load lazily");
        registry.requestTimeWeatherTab("time");
        registry.requestTimeWeatherTab("weather");
        tryVerify(function () {
            return registry.controllerFor("time-weather") !== null;
        });
        compare(registry.controllerFor("time-weather").detailsTab, "weather");
        registry.requestTimeWeatherTab("time");
        compare(registry.controllerFor("time-weather").detailsTab, "time");

        registry.openNotifications("Mail", "history", "activity");
        tryVerify(function () {
            return registry.notificationController !== null;
        });
        compare(registry.notificationController.pendingGroupKey, "Mail");
        compare(registry.notificationController.returnSurface, "activity");
        compare(registry.notificationController.notificationState, registry.notificationState);
        registry.openNotifications("Other", "notifications", "applications");
        compare(registry.notificationController.pendingGroupKey, "Other");
        compare(registry.notificationController.returnSurface, "applications");
    }

}
