pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import Shelllist.Core as Core
import Shelllist.Ui as Ui
import Shelllist.Wifi as Wifi
import Shelllist.Bluetooth as Bluetooth
import Shelllist.Clipboard as Clipboard
import Shelllist.Launcher as Launcher
import Shelllist.Activity as Activity
import Shelllist.Battery as Battery
import Shelllist.Displays as Displays

Item {
    id: registry

    readonly property var descriptors: [
        {
            id: "applications",
            name: "Applications",
            icon: "󰀻"
        },
        {
            id: "wifi",
            name: "Wi-Fi",
            icon: "󰖩"
        },
        {
            id: "bluetooth",
            name: "Bluetooth",
            icon: "󰂯"
        },
        {
            id: "clipboard",
            name: "Clipboard",
            icon: "󰅇"
        },
        {
            id: "displays",
            name: "Displays",
            icon: "󰍹"
        },
        {
            id: "battery",
            name: "Battery",
            icon: "󰂂"
        },
        {
            id: "activity",
            name: "Activity",
            icon: "󰃭"
        },
        {
            id: "notifications",
            name: "Notifications",
            icon: ""
        },
        {
            id: "time-weather",
            name: "Time & Weather",
            icon: "󰅐"
        }
    ]
    property var loadedSurfaces: ({
            wifi: true,
            bluetooth: true
        })
    property var openedSurfaces: ({})
    property string currentId: "applications"
    readonly property alias notificationState: sharedNotifications

    Core.DraftStore {
        id: pendingActions
    }

    Activity.NotificationState {
        id: sharedNotifications
        uiActive: (registry.activityController !== null && registry.activityController.uiActive) || (registry.notificationController !== null && registry.notificationController.uiActive)
        historyEnabled: uiActive
    }

    readonly property var currentDescriptor: descriptorFor(currentId)
    readonly property Ui.ChooserController currentController: controllerFor(currentId)
    readonly property var wifiController: controllerFor("wifi")
    readonly property var bluetoothController: controllerFor("bluetooth")
    readonly property var displayController: controllerFor("displays")
    readonly property var activityController: controllerFor("activity")
    readonly property var notificationController: controllerFor("notifications")

    signal surfaceRequested(string surfaceId)
    signal surfaceReady(string surfaceId)

    function descriptorFor(surfaceId: string): var {
        return descriptors.find(function (descriptor) {
            return descriptor.id === surfaceId;
        }) || null;
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
        for (let index = 0; index < children.length; ++index) {
            const slot = children[index] as SurfaceSlot;
            if (slot && slot.surfaceId === surfaceId)
                return slot.bundle;
        }
        return null;
    }

    function controllerFor(surfaceId: string): Ui.ChooserController {
        const bundle = bundleFor(surfaceId);
        return bundle ? bundle.controller : null;
    }

    function ensureLoaded(surfaceId: string): bool {
        const id = validSurfaceId(surfaceId);
        if (id.length === 0)
            return false;
        markLoaded(id);
        return true;
    }

    function select(surfaceId: string): bool {
        const id = validSurfaceId(surfaceId);
        if (id.length === 0 || !ensureLoaded(id))
            return false;
        markOpened(id);
        currentId = id;
        return true;
    }

    // Runs action(controller) once the surface's controller exists, replacing
    // any earlier request for the same surface.
    function whenReady(surfaceId: string, action: var): void {
        pendingActions.put(surfaceId, action);
        ensureLoaded(surfaceId);
        applyPending(surfaceId);
    }

    function applyPending(surfaceId: string): void {
        const action = pendingActions.draft(surfaceId);
        const controller = controllerFor(surfaceId);
        if (!action || !controller)
            return;
        pendingActions.put(surfaceId, null);
        action(controller);
    }

    function requestTimeWeatherTab(tab: string): void {
        const target = tab === "weather" ? "weather" : "time";
        whenReady("time-weather", function (controller) {
            controller.setDetailsTab(target);
        });
    }

    function openTimeWeather(tab: string): void {
        requestTimeWeatherTab(tab);
        surfaceRequested("time-weather");
    }

    function openNotifications(groupKey: string, tab: string, origin: string): void {
        whenReady("notifications", function (controller) {
            controller.openNotifications(groupKey || "", tab || "active", origin || "");
        });
        surfaceRequested("notifications");
    }

    function notifySurfaceReady(surfaceId: string): void {
        applyPending(surfaceId);
        surfaceReady(surfaceId);
    }

    function listJson(): string {
        return JSON.stringify(descriptors);
    }

    Component.onCompleted: {
        const initial = validSurfaceId(Quickshell.env("SHELLLIST_INITIAL_SURFACE"));
        if (initial.length > 0)
            select(initial);
    }

    SurfaceSlot {
        surfaceId: "applications"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: applicationController
                content: Component {
                    Launcher.ApplicationContent {
                        controller: applicationController
                    }
                }
                Launcher.ApplicationController {
                    id: applicationController
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "wifi"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: wifiController
                content: Component {
                    Wifi.WifiContent {
                        controller: wifiController
                    }
                }
                Wifi.WifiPromptController {
                    id: wifiPromptController
                }
                Wifi.WifiController {
                    id: wifiController
                    prompt: wifiPromptController
                    statusMonitorActive: true
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "bluetooth"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: bluetoothController
                content: Component {
                    Bluetooth.BluetoothContent {
                        controller: bluetoothController
                    }
                }
                Bluetooth.BluetoothController {
                    id: bluetoothController
                    onPairingInteractionRequested: registry.surfaceRequested("bluetooth")
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "displays"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: displayController
                content: Component {
                    Displays.DisplayContent {
                        controller: displayController
                    }
                }
                Displays.DisplayController {
                    id: displayController
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "battery"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: batteryController
                content: Component {
                    Battery.BatteryContent {
                        controller: batteryController
                    }
                }
                Battery.BatteryController {
                    id: batteryController
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "activity"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: activityController
                content: Component {
                    Activity.ActivityContent {
                        controller: activityController
                    }
                }
                Activity.ActivityController {
                    id: activityController
                    notificationState: registry.notificationState
                    onTimeWeatherRequested: function (tab) {
                        registry.openTimeWeather(tab);
                    }
                    onNotificationsRequested: function (groupKey, tab) {
                        registry.openNotifications(groupKey, tab, "activity");
                    }
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "notifications"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: notificationController
                content: Component {
                    Activity.NotificationContent {
                        controller: notificationController
                    }
                }
                Activity.NotificationController {
                    id: notificationController
                    notificationState: registry.notificationState
                    onBackRequested: registry.surfaceRequested("activity")
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "time-weather"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: timeWeatherController
                content: Component {
                    Activity.TimeWeatherContent {
                        controller: timeWeatherController
                    }
                }
                Activity.TimeWeatherController {
                    id: timeWeatherController
                }
            }
        }
    }

    SurfaceSlot {
        surfaceId: "clipboard"
        owner: registry
        sourceComponent: Component {
            SurfaceBundle {
                controller: clipboardController
                content: Component {
                    Clipboard.ClipboardContent {
                        controller: clipboardController
                    }
                }
                Clipboard.ClipboardController {
                    id: clipboardController
                }
            }
        }
    }
}
