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
import Shelllist.Bar as Bar
import "SurfaceCatalog.generated.js" as Catalog

Item {
    id: registry

    property Bar.BarController barController: null
    readonly property var descriptors: Catalog.descriptors
    property var loadedSurfaces: Catalog.initiallyLoaded()
    property var openedSurfaces: ({})
    property string currentId: Catalog.defaultSurface
    readonly property alias notificationState: sharedNotifications

    Core.DraftStore {
        id: pendingActions
    }

    Activity.NotificationState {
        id: sharedNotifications
        resident: Catalog.requiresResidentState("notifications")
        uiActive: registry.notificationController !== null && registry.notificationController.uiActive
    }

    readonly property var currentDescriptor: descriptorFor(currentId)
    readonly property Ui.ChooserController currentController: controllerFor(currentId)
    readonly property Wifi.WifiController wifiController: controllerFor("wifi") as Wifi.WifiController
    readonly property Bluetooth.BluetoothController bluetoothController: controllerFor("bluetooth") as Bluetooth.BluetoothController
    readonly property Displays.DisplayController displayController: controllerFor("displays") as Displays.DisplayController
    readonly property Activity.NotificationController notificationController: controllerFor("notifications") as Activity.NotificationController

    signal surfaceRequested(string surfaceId)
    signal surfaceReady(string surfaceId)

    function descriptorFor(surfaceId: string): var {
        return descriptors.find(function (descriptor) {
            return descriptor.id === surfaceId;
        }) || null;
    }

    function validSurfaceId(surfaceId: string): string {
        const requested = String(surfaceId || "").toLowerCase();
        // Compatibility only: no third scheduling surface or controller.
        const canonical = requested === "activity" ? "agenda" : requested;
        return descriptorFor(canonical) ? canonical : "";
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

    component SystemSlot: SurfaceSlot {
        id: systemSlot
        owner: registry
        sourceComponent: SurfaceBundle {
            controller: systemController
            content: Bar.SystemChooserContent { controller: systemController }
            Bar.SystemChooserController {
                id: systemController
                kind: systemSlot.surfaceId
                barController: registry.barController
            }
        }
    }
    SystemSlot { surfaceId: "audio" }
    SystemSlot { surfaceId: "media" }
    SystemSlot { surfaceId: "tray" }

    SurfaceSlot {
        surfaceId: "updates"
        owner: registry
        sourceComponent: SurfaceBundle {
            controller: updateController
            content: Bar.UpdateContent { controller: updateController }
            Bar.UpdateController { id: updateController; barController: registry.barController }
        }
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
                    onBackgroundActionFailed: function (title, message) {
                        // Separate arguments, never a shell command; notification
                        // markup must not interpret application-supplied text.
                        const body = message.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
                        Quickshell.execDetached(["notify-send", "--app-name=Shelllist", "--icon=dialog-error", "--", "Application action: " + title, body]);
                    }
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
        surfaceId: "agenda"
        owner: registry
        sourceComponent: SurfaceBundle {
            controller: agendaController
            content: Activity.AgendaContent { controller: agendaController }
            Activity.AgendaController { id: agendaController }
        }
    }

    SurfaceSlot {
        surfaceId: "calendar"
        owner: registry
        sourceComponent: SurfaceBundle {
            controller: calendarController
            content: Activity.AgendaCalendarContent { controller: calendarController }
            Activity.AgendaCalendarController { id: calendarController }
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
                    onBackRequested: registry.surfaceRequested("agenda")
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
