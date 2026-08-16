pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Ui as Ui
import Shelllist.Wifi as Wifi
import Shelllist.Bluetooth as Bluetooth
import Shelllist.Clipboard as Clipboard
import Shelllist.Launcher as Launcher

Item {
    id: registry

    readonly property var descriptors: [
        { id: "applications", name: "Applications", icon: "󰀻" },
        { id: "wifi", name: "Wi-Fi", icon: "󰖩" },
        { id: "bluetooth", name: "Bluetooth", icon: "󰂯" },
        { id: "clipboard", name: "Clipboard", icon: "󰅇" }
    ]
    property var loadedSurfaces: ({ wifi: true, bluetooth: true })
    property var openedSurfaces: ({})
    property string currentId: "applications"

    readonly property SurfaceBundle currentBundle: bundleFor(currentId)
    readonly property Ui.ChooserController currentController: currentBundle
        ? currentBundle.controller : null
    readonly property var wifiController: {
        const bundle = bundleFor("wifi");
        return bundle ? bundle.controller : null;
    }
    readonly property var bluetoothController: {
        const bundle = bundleFor("bluetooth");
        return bundle ? bundle.controller : null;
    }

    signal surfaceRequested(string surfaceId)

    function descriptorFor(surfaceId: string): var {
        return descriptors.find(function (descriptor) { return descriptor.id === surfaceId; }) || null;
    }

    function validSurfaceId(surfaceId: string): string {
        const requested = String(surfaceId || "").toLowerCase();
        return descriptorFor(requested) ? requested : "";
    }

    function isLoaded(surfaceId: string): bool {
        return loadedSurfaces[surfaceId] === true;
    }

    function markLoaded(surfaceId: string): void {
        if (isLoaded(surfaceId))
            return;
        const next = Object.assign({}, loadedSurfaces);
        next[surfaceId] = true;
        loadedSurfaces = next;
    }

    function wasOpened(surfaceId: string): bool {
        return openedSurfaces[surfaceId] === true;
    }

    function markOpened(surfaceId: string): void {
        if (wasOpened(surfaceId))
            return;
        const next = Object.assign({}, openedSurfaces);
        next[surfaceId] = true;
        openedSurfaces = next;
    }

    function bundleFor(surfaceId: string): SurfaceBundle {
        const bundles = ({
            applications: applicationBundle.item,
            wifi: wifiBundle.item,
            bluetooth: bluetoothBundle.item,
            clipboard: clipboardBundle.item
        });
        return bundles[surfaceId] || null;
    }

    function ensureLoaded(surfaceId: string): bool {
        const id = validSurfaceId(surfaceId);
        if (id.length === 0)
            return false;
        markLoaded(id);
        return bundleFor(id) !== null;
    }

    function select(surfaceId: string): bool {
        const id = validSurfaceId(surfaceId);
        if (id.length === 0 || !ensureLoaded(id))
            return false;
        markOpened(id);
        currentId = id;
        return true;
    }

    function listJson(): string {
        return JSON.stringify(descriptors);
    }

    Component.onCompleted: {
        const initial = validSurfaceId(Quickshell.env("SHELLLIST_INITIAL_SURFACE"));
        if (initial.length > 0)
            select(initial);
    }

    Loader {
        id: applicationBundle
        active: registry.isLoaded("applications")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "applications"
                displayName: "Applications"
                icon: "󰀻"
                controller: applicationController
                content: Component {
                    Launcher.ApplicationContent { controller: applicationController }
                }
                Launcher.ApplicationController { id: applicationController }
            }
        }
    }

    Loader {
        id: wifiBundle
        active: registry.isLoaded("wifi")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "wifi"
                displayName: "Wi-Fi"
                icon: "󰖩"
                controller: wifiController
                content: Component {
                    Wifi.WifiContent { controller: wifiController }
                }
                Wifi.WifiPromptController { id: wifiPromptController }
                Wifi.WifiController {
                    id: wifiController
                    prompt: wifiPromptController
                    statusMonitorActive: true
                }
            }
        }
    }

    Loader {
        id: bluetoothBundle
        active: registry.isLoaded("bluetooth")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "bluetooth"
                displayName: "Bluetooth"
                icon: "󰂯"
                controller: bluetoothController
                content: Component {
                    Bluetooth.BluetoothContent { controller: bluetoothController }
                }
                Bluetooth.BluetoothController {
                    id: bluetoothController
                    onPairingInteractionRequested: registry.surfaceRequested("bluetooth")
                }
            }
        }
    }

    Loader {
        id: clipboardBundle
        active: registry.isLoaded("clipboard")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "clipboard"
                displayName: "Clipboard"
                icon: "󰅇"
                controller: clipboardController
                content: Component {
                    Clipboard.ClipboardContent { controller: clipboardController }
                }
                Clipboard.ClipboardController { id: clipboardController }
            }
        }
    }
}
