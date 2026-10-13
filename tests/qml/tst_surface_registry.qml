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

    function test_catalogPreservesPublicDescriptorsAndLoadingPolicy(): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        verify(registry !== null);
        compare(registry.currentId, "applications");
        compare(registry.descriptors.map(item => item.id), [
            "applications", "wifi", "bluetooth", "clipboard", "displays", "battery",
            "activity", "notifications", "time-weather", "audio", "media", "tray"
        ]);
        compare(JSON.parse(registry.listJson()), registry.descriptors);
        const slots = Array.from(registry.children).filter(child => child instanceof Shell.SurfaceSlot);
        compare(slots.map(slot => slot.surfaceId).sort(), registry.descriptors.map(item => item.id).sort());
        slots.forEach(slot => compare(slot.owner, registry));
        compare(Object.keys(registry.loadedSurfaces).sort(), ["bluetooth", "wifi"]);
        compare(Object.keys(registry.openedSurfaces), []);
        verify(registry.notificationState.resident);
        compare(registry.notificationController, null);
        verify(registry.notificationState.backend.active);
        registry.descriptors.forEach(function (descriptor) {
            // listSurfaces remains the public descriptor API, not the internal schema.
            compare(Object.keys(descriptor).sort(), ["icon", "id", "name"]);
            if (Catalog.eagerSurfaceIds.indexOf(descriptor.id) >= 0)
                tryVerify(() => registry.controllerFor(descriptor.id) !== null);
            else
                compare(registry.controllerFor(descriptor.id), null, descriptor.id + " must stay lazy");
        });
    }

    function test_everySurfaceHasTypedControllerAndContent_data(): var {
        return Catalog.descriptors.map(item => ({tag: item.id, surfaceId: item.id}));
    }

    function test_everySurfaceHasTypedControllerAndContent(data): void {
        const registry = createTemporaryObject(registryComponent, testCase);
        verify(registry !== null);
        verify(registry.select(data.surfaceId.toUpperCase()));
        compare(registry.currentId, data.surfaceId);
        verify(registry.wasOpened(data.surfaceId));
        tryVerify(() => registry.bundleFor(data.surfaceId) !== null);
        verify(registry.currentController !== null);
        compare(registry.currentController, registry.controllerFor(data.surfaceId));
        const content = createTemporaryObject(registry.bundleFor(data.surfaceId).content, testCase, {width: 800, height: 600});
        verify(content !== null, data.surfaceId + " content factory");
        compare(content.controller, registry.currentController);
        Catalog.descriptors.forEach(function (item) {
            if (item.id !== data.surfaceId && Catalog.eagerSurfaceIds.indexOf(item.id) < 0)
                compare(registry.controllerFor(item.id), null, item.id);
        });
        if (data.surfaceId === "notifications")
            compare(registry.notificationController.notificationState, registry.notificationState);
    }

    function test_initialSurfaceDeepLinks_data(): var {
        // Eager, lazy and invalid startup paths; selection tests cover all IDs.
        return ["wifi", "clipboard", "unknown"].map(id => ({tag: id, surfaceId: id}));
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
