pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import "../../shell" as Shell
import "../../shell/SurfaceCatalog.generated.js" as Catalog

DaemonTestCase {
    id: testCase
    name: "SurfaceShortcuts"
    when: windowShown

    Component {
        id: fixtureComponent
        Item {
            id: fixture
            property alias registry: registry
            property alias shortcuts: shortcuts
            Shell.SurfaceRegistry { id: registry }
            Shell.SurfaceShortcuts {
                id: shortcuts
                onSurfaceRequested: function (surfaceId) { fixture.registry.select(surfaceId); }
            }
        }
    }

    SignalSpy { id: requests; signalName: "surfaceRequested" }

    function test_surfaceShortcutRouting_data(): var {
        // Default, eager and hyphenated lazy IDs exercise the shared delegate.
        return ["applications", "wifi", "time-weather"].map(id => {
            const item = Catalog.descriptors.find(item => item.id === id);
            return {tag: id, surfaceId: id, label: item.name};
        });
    }

    function test_surfaceShortcutRouting(data): void {
        const fixture = createTemporaryObject(fixtureComponent, testCase);
        verify(fixture !== null);
        requests.target = fixture.shortcuts;
        requests.clear();
        const shortcut = findChild(fixture.shortcuts, "surfaceShortcut-" + data.surfaceId);
        verify(shortcut !== null);
        compare(shortcut.shortcutName, data.surfaceId);
        compare(shortcut.description, "Toggle Shelllist " + data.label);
        const registration = findChild(shortcut, "registeredShortcut-shelllist:" + data.surfaceId);
        verify(registration !== null);
        compare(registration.appid, "shelllist");
        compare(registration.name, data.surfaceId);
        compare(registration.description, shortcut.description);
        // Exercise the real wrapper and catalog delegate, not a copied JS router.
        // Only the compositor's registration/pressed source is mocked.
        registration.pressed();
        compare(requests.count, 1);
        compare(requests.signalArguments[0][0], data.surfaceId);
        compare(fixture.registry.currentId, data.surfaceId);
        tryVerify(() => fixture.registry.currentController !== null);
        requests.target = null;
    }

    function test_registrationDoesNotPreloadSurfacesOrIncludeEffects(): void {
        const fixture = createTemporaryObject(fixtureComponent, testCase);
        verify(fixture !== null);
        compare(Array.from(fixture.shortcuts.children).filter(child => child.objectName.indexOf("surfaceShortcut-") === 0).length, 12);
        compare(Object.keys(fixture.registry.loadedSurfaces).sort(), ["bluetooth", "wifi"]);
        compare(Object.keys(fixture.registry.openedSurfaces), []);
        ["shell", "update-logs", "volume-up", "brightness-up"].forEach(function (id) {
            compare(findChild(fixture.shortcuts, "surfaceShortcut-" + id), null);
        });
    }
}
