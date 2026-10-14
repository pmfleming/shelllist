pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../shell" as Shell
import "../../shell/SurfaceCatalog.generated.js" as Catalog

DaemonTestCase {
    id: testCase
    name: "SurfaceRegistry"
    when: windowShown
    visible: true
    width: 400
    height: 400
    // The mock's environment map is not part of production Quickshell type info.
    readonly property var quickshellMock: Quickshell

    Component {
        id: registryComponent
        Shell.SurfaceRegistry {}
    }

    function test_initialSurfaceDeepLinks_data(): var {
        return ["wifi"].map(id => ({tag: id, surfaceId: id}));
    }

    function test_initialSurfaceDeepLinks(data): void {
        const previous = quickshellMock.environment;
        let registry = null;
        try {
            quickshellMock.environment = {SHELLLIST_INITIAL_SURFACE: data.surfaceId};
            registry = createTemporaryObject(registryComponent, testCase);
        } finally {
            quickshellMock.environment = previous;
        }
        verify(registry !== null);
        if (data.surfaceId === "unknown") {
            compare(registry.currentId, Catalog.defaultSurface);
            compare(Object.keys(registry.openedSurfaces), []);
        } else {
            compare(registry.currentId, data.surfaceId);
            verify(registry.wasOpened(data.surfaceId));
            tryVerify(() => registry.currentController !== null);
        }
    }

    function test_unknownIdsDoNotLoadOrSelect(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        ["", "unknown", "applications;quit", "time_weather"].forEach(function (id) {
            verify(!registry.select(id));
            compare(registry.bundleFor(id), null);
        });
        compare(registry.currentId, "applications");
        compare(Object.keys(registry.loadedSurfaces).sort(), ["bluetooth", "wifi"]);
        compare(Object.keys(registry.openedSurfaces), []);
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
