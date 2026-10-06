pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui
import "imports/Quickshell/Services/SystemTray" as Tray

TestCase {
    id: testCase
    name: "MaterialBar"
    when: windowShown
    visible: true
    width: 1200
    height: 70
    Component {
        id: barFactory
        Bar.BarContent {
            height: 51
            screenName: "test"
            controller: Bar.BarController {
                surfaceRegistry: null
                backend.active: false
                battery: ({available: true, percentage: 80})
                notifications: ({count: 17, dnd: false})
            }
        }
    }
    Component {
        id: trayFactory
        Bar.BarTrayItem {
            width: 32; height: 37
            menuWindow: QtObject {}
        }
    }
    Component {
        id: trayItemFactory
        Tray.SystemTrayItem { title: "Test application" }
    }
    Component {
        id: registryFactory
        QtObject {
            property var wifiController: null
            property var bluetoothController: null
            property var notificationState: null
            property string requestedSurface: ""
            function surfaceRequested(id: string): void { requestedSurface = id; }
        }
    }
    function init(): void { failOnWarning(/.*/); }
    function cleanup(): void { Tray.SystemTray.items.values = []; }
    function actionControls(item): var {
        if (item instanceof Ui.ActionControl) return [item];
        let controls = [];
        for (const child of item.children) controls = controls.concat(actionControls(child));
        return controls;
    }
    function test_mediaArtworkUsesSoftFeedbackAndDarkBacking(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 1200});
        const button = findChild(bar, "mediaArtworkButton");
        const backdrop = findChild(button, "mediaArtworkBackdrop");
        verify(waitForPolish(bar.Window.window));
        verify(waitForRendering(button));
        verify(!backdrop.visible, "no empty artwork tile behind the media glyph");
        mouseMove(testCase, testCase.width - 1, testCase.height - 1);
        mouseMove(button, 1, button.height / 2);
        tryCompare(button, "color", Ui.Theme.hover);
        compare(button.labelColor, Ui.Theme.text);
        button.forceActiveFocus();
        compare(button.color, Ui.Theme.hover);
        bar.controller.media = {available: true, active_player: "player", players: [{
            id: "player", identity: "Player", playback_status: "Playing",
            art_url: Qt.resolvedUrl("../../qml/Shelllist/Activity/assets/weather/clear-night.svg").toString()
        }]};
        tryCompare(backdrop, "visible", true);
        verify(waitForPolish(bar.Window.window));
        compare(backdrop.color, Ui.Theme.window);
        mousePress(button, 1, button.height / 2);
        compare(button.color, Ui.Theme.pressed);
        compare(backdrop.color, Ui.Theme.window, "press feedback never lightens transparent artwork");
        mouseRelease(button, 1, button.height / 2);
        compare(button.color, Ui.Theme.hover);
        compare(backdrop.color, Ui.Theme.window);
        bar.controller.media = {available: false, players: []};
        tryCompare(backdrop, "visible", false);
        verify(button.icon.length > 0, "the media glyph returns when artwork disappears");
    }
    function test_topBarControlsNeverShowPanelCaret(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 1200});
        bar.controller.media = {available: true, active_player: "player", players: [{id: "player", identity: "Player", playback_status: "Playing", can_control: true, can_pause: true, can_play: true, can_previous: true, can_next: true}]};
        tryVerify(() => findChild(bar, "bar:network") !== null);
        tryVerify(() => findChild(bar, "mediaPlayPauseButton").visible);
        const controls = actionControls(bar);
        verify(controls.length >= 12, "includes workspaces, status, media, tray and overflow controls");
        for (const control of controls) {
            compare(control.browseIndicatorVisible, false, control.objectName || control.accessibleName);
            verify(!control.activeFocusOnTab, "bar controls do not gain Tab traversal");
            if (!control.visible || !control.enabled) continue;
            control.forceActiveFocus();
            verify(control.activeFocus);
            verify(findChild(control, "focusRing").visible, "tonal focus feedback remains");
            verify(!findChild(control, "browseFocusIndicator").visible, "top bar has no panel caret");
        }
        bar.width = 300;
        tryCompare(bar, "overflow", true);
        const overflow = findChild(bar, "barOverflowButton");
        mouseClick(overflow, overflow.width / 2, overflow.height / 2);
        verify(overflow.activeFocus);
        verify(!findChild(overflow, "browseFocusIndicator").visible);
        verify(findChild(bar, "barOverflowViewport").contentX > 0, "overflow remains reachable by pointer");
    }
    function test_trayItemsStayBehindEllipsisAtEveryDensity(): void {
        const tray = createTemporaryObject(trayItemFactory, testCase);
        Tray.SystemTray.items.values = [tray];
        const registry = createTemporaryObject(registryFactory, testCase);
        const bar = createTemporaryObject(barFactory, testCase, {width: 1200});
        bar.controller.surfaceRegistry = registry;
        const group = findChild(bar, "barTray");
        const button = findChild(group, "barTrayButton");
        for (const width of [2000, 1200, 900, 600]) {
            bar.width = width;
            verify(waitForRendering(button));
            compare(group.implicitWidth, 32, "tray never reserves space for application icons");
            const controls = actionControls(group);
            compare(controls.length, 1, "only the ellipsis is rendered, never an inline tray item");
            compare(controls[0], button);
        }
        bar.width = 1200;
        verify(waitForRendering(button));
        mouseClick(button, button.width / 2, button.height / 2);
        compare(registry.requestedSurface, "tray");
        compare(tray.activationCount, 0);
        Tray.SystemTray.items.values = [];
        verify(button.visible, "empty tray remains accessible");
        compare(group.implicitWidth, 32);
    }
    function test_trayAssistivePressUsesPointerPrimaryRoute(): void {
        const tray = createTemporaryObject(trayItemFactory, testCase);
        const button = createTemporaryObject(trayFactory, testCase, {item: tray});
        compare(button.Accessible.role, Accessible.Button);
        compare(button.Accessible.name, "Test application");
        verify(!button.activeFocusOnTab, "the bar does not gain keyboard traversal");
        button.Accessible.pressAction();
        compare(button.item.activationCount, 1);
        mouseClick(button, 16, 18);
        compare(button.item.activationCount, 2);
        button.enabled = false;
        button.Accessible.pressAction();
        compare(button.item.activationCount, 2);
        button.enabled = true;
        button.visible = false;
        button.Accessible.pressAction();
        compare(button.item.activationCount, 2);
        button.visible = true;
        button.item.onlyMenu = true;
        button.Accessible.pressAction();
        compare(button.item.activationCount, 2, "menu-only items never fall back to activation");
        compare(button.item.menuCount, 0, "missing menus are not dispatched");
        button.item.hasMenu = true;
        button.Accessible.pressAction();
        compare(button.item.menuCount, 1);
        compare(button.item.lastMenuWindow, button.menuWindow);
        mouseClick(button, 16, 18);
        compare(button.item.menuCount, 2, "pointer and assistive routes preserve menu-only behavior");
        compare(button.item.activationCount, 2);
        compare(button.item.secondaryCount, 0);
        button.item = null;
        button.Accessible.pressAction();
        button.routeClick(Qt.RightButton);
        button.scroll(120);
        compare(button.Accessible.name, "");
        compare(tray.menuCount, 2, "a removed tray item cannot receive late actions");
        compare(tray.scrollTotal, 0);
    }
    function test_popupVisibilityIsIndependentOfLiveNotificationCount(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        bar.controller.workspaces = {monitors: [{name: "test"}], focused_monitor: "test"};
        bar.controller.notificationActive = {notifications: [
            {id: 1, group_key: "mail", toast_visible: false},
            {id: 2, group_key: "chat", toast_visible: true}
        ]};
        compare(bar.controller.visibleToastGroups("test").length, 1);
        compare(bar.controller.visibleToastGroups("test")[0].key, "chat");
        compare(bar.controller.notificationActive.notifications.length, 2, "hidden popup remains live in the center");
        bar.controller.notifications = {count: 2, dnd: true};
        compare(bar.controller.visibleToastGroups("test").length, 0);
    }
    function test_unknownRoutesCannotCallObjectPrototypeMethods(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        for (const name of ["missing", "__proto__", "constructor", "toString"])
            verify(!bar.controller.triggerModuleAction(name));
    }
}
