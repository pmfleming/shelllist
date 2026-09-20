pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
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
    property string pendingActivitySection: ""
    property string pendingTimeWeatherTab: ""
    property var pendingNotificationRequest: null
    readonly property alias notificationState: sharedNotifications
    readonly property var notificationController: {
        const bundle = bundleFor("notifications");
        return bundle ? bundle.controller : null;
    }

    Activity.NotificationState {
        id: sharedNotifications
        uiActive: (registry.activityController !== null && registry.activityController.uiActive) || (registry.notificationController !== null && registry.notificationController.uiActive)
        historyEnabled: uiActive
    }

    readonly property SurfaceBundle currentBundle: bundleFor(currentId)
    readonly property Ui.ChooserController currentController: currentBundle ? currentBundle.controller : null
    readonly property var wifiController: {
        const bundle = bundleFor("wifi");
        return bundle ? bundle.controller : null;
    }
    readonly property var bluetoothController: {
        const bundle = bundleFor("bluetooth");
        return bundle ? bundle.controller : null;
    }
    readonly property var displayController: {
        const bundle = bundleFor("displays");
        return bundle ? bundle.controller : null;
    }
    readonly property var activityController: {
        const bundle = bundleFor("activity");
        return bundle ? bundle.controller : null;
    }

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
        const bundles = ({
                applications: applicationBundle.item,
                wifi: wifiBundle.item,
                bluetooth: bluetoothBundle.item,
                clipboard: clipboardBundle.item,
                battery: batteryBundle.item,
                displays: displayBundle.item,
                activity: activityBundle.item,
                notifications: notificationBundle.item,
                "time-weather": timeWeatherBundle.item
            });
        return bundles[surfaceId] || null;
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

    function requestActivitySection(section: string): void {
        if (section === "notifications") {
            openNotifications("", "active", "");
            return;
        }
        pendingActivitySection = section;
        ensureLoaded("activity");
        applyPendingActivitySection();
    }

    function applyPendingActivitySection(): void {
        if (pendingActivitySection.length === 0 || !activityController)
            return;
        activityController.openSection(pendingActivitySection);
        pendingActivitySection = "";
    }

    function requestTimeWeatherTab(tab: string): void {
        pendingTimeWeatherTab = tab === "weather" ? "weather" : "time";
        ensureLoaded("time-weather");
        applyPendingTimeWeatherTab();
    }

    function applyPendingTimeWeatherTab(): void {
        const bundle = bundleFor("time-weather");
        const timeWeatherController = bundle ? bundle.controller : null;
        if (pendingTimeWeatherTab.length === 0 || !timeWeatherController)
            return;
        timeWeatherController.setDetailsTab(pendingTimeWeatherTab);
        pendingTimeWeatherTab = "";
    }

    function openTimeWeather(tab: string): void {
        requestTimeWeatherTab(tab);
        surfaceRequested("time-weather");
    }

    function openNotifications(groupKey: string, tab: string, origin: string): void {
        pendingNotificationRequest = {
            key: groupKey || "",
            tab: tab || "active",
            origin: origin || ""
        };
        ensureLoaded("notifications");
        applyPendingNotifications();
        surfaceRequested("notifications");
    }

    function applyPendingNotifications(): void {
        if (!pendingNotificationRequest || !notificationController)
            return;
        const request = pendingNotificationRequest;
        pendingNotificationRequest = null;
        notificationController.openNotifications(request.key, request.tab, request.origin);
    }

    function openDisplays(): void {
        surfaceRequested("displays");
    }

    function notifySurfaceReady(surfaceId: string): void {
        if (surfaceId === "activity")
            applyPendingActivitySection();
        else if (surfaceId === "time-weather")
            applyPendingTimeWeatherTab();
        else if (surfaceId === "notifications")
            applyPendingNotifications();
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

    Loader {
        id: applicationBundle
        active: registry.isLoaded("applications")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("applications")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "applications"
                displayName: "Applications"
                icon: "󰀻"
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

    Loader {
        id: wifiBundle
        active: registry.isLoaded("wifi")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("wifi")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "wifi"
                displayName: "Wi-Fi"
                icon: "󰖩"
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

    Loader {
        id: bluetoothBundle
        active: registry.isLoaded("bluetooth")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("bluetooth")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "bluetooth"
                displayName: "Bluetooth"
                icon: "󰂯"
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

    Loader {
        id: displayBundle
        active: registry.isLoaded("displays")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("displays")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "displays"
                displayName: "Displays"
                icon: "󰍹"
                controller: displayController
                content: Component {
                    Displays.DisplayContent { controller: displayController }
                }
                Displays.DisplayController { id: displayController }
            }
        }
    }

    Loader {
        id: batteryBundle
        active: registry.isLoaded("battery")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("battery")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "battery"
                displayName: "Battery"
                icon: "󰂂"
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

    Loader {
        id: activityBundle
        active: registry.isLoaded("activity")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("activity")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "activity"
                displayName: "Activity"
                icon: "󰃭"
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

    Loader {
        id: notificationBundle
        active: registry.isLoaded("notifications")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("notifications")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "notifications"
                displayName: "Notifications"
                icon: ""
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

    Loader {
        id: timeWeatherBundle
        active: registry.isLoaded("time-weather")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("time-weather")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "time-weather"
                displayName: "Time & Weather"
                icon: "󰅐"
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

    Loader {
        id: clipboardBundle
        active: registry.isLoaded("clipboard")
        asynchronous: true
        onLoaded: registry.notifySurfaceReady("clipboard")
        sourceComponent: Component {
            SurfaceBundle {
                surfaceId: "clipboard"
                displayName: "Clipboard"
                icon: "󰅇"
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
