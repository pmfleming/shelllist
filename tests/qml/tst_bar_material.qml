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
        id: actionFactory
        Bar.BarAction {
            text: "wifi"
            property int primaryCalls: 0
            property int secondaryCalls: 0
            property int middleCalls: 0
            onPrimaryTriggered: primaryCalls++
            onSecondaryTriggered: secondaryCalls++
            onMiddleTriggered: middleCalls++
        }
    }
    Component {
        id: panelActionFactory
        Ui.ActionButton { icon: "wifi"; label: "Panel command" }
    }
    function init(): void { failOnWarning(/.*/); }
    function actionControls(item): var {
        if (item instanceof Ui.ActionControl) return [item];
        let controls = [];
        for (const child of item.children) controls = controls.concat(actionControls(child));
        return controls;
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
    }
    function test_barPointerAndKeyboardRoutesKeepFeedbackWithoutCaret(): void {
        const button = createTemporaryObject(actionFactory, testCase);
        verify(waitForRendering(button));
        mousePress(button, 16, 16);
        verify(button.activeFocus);
        verify(findChild(button, "focusRing").visible);
        verify(!findChild(button, "browseFocusIndicator").visible);
        mouseRelease(button, 16, 16);
        compare(button.primaryCalls, 1);
        mouseClick(button, 16, 16, Qt.RightButton);
        compare(button.secondaryCalls, 1);
        mouseClick(button, 16, 16, Qt.MiddleButton);
        compare(button.middleCalls, 1);
        keyClick(Qt.Key_Return);
        compare(button.primaryCalls, 2);
        button.enabled = false;
        mouseClick(button, 16, 16);
        button.activate();
        compare(button.primaryCalls, 2, "disabled commands remain guarded");

        const panelButton = createTemporaryObject(panelActionFactory, testCase);
        panelButton.forceActiveFocus();
        verify(findChild(panelButton, "browseFocusIndicator").visible, "panel command feedback is unchanged");
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
    function test_emergencyOverflowKeepsGroupsReachable(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 300});
        tryVerify(() => findChild(bar, "bar:notifications") !== null);
        verify(waitForRendering(bar));
        const names = ["barWorkspaces", "barMedia", "bar:network", "bar:bluetooth", "bar:battery", "bar:notifications", "barTray", "barClock"];
        let edge = -1;
        for (const name of names) {
            const item = findChild(bar, name);
            verify(item !== null && item.visible, name);
            const x = item.mapToItem(bar, 0, 0).x;
            verify(x >= edge, name + " must follow the preceding group without overlap");
            edge = x + item.width;
        }
        verify(!findChild(bar, "bar:battery").text.includes("80"));
        verify(!findChild(bar, "bar:notifications").text.includes("17"));
        verify(findChild(bar, "bar:battery").accessibleName.includes("80"));
        verify(findChild(bar, "barClock").text.includes(":"));
        compare(bar.visualSurface.radius, 20);
        verify(bar.overflow);
        const viewport = findChild(bar, "barOverflowViewport");
        const button = findChild(bar, "barOverflowButton");
        verify(button.width >= 32 && button.height >= 32);
        verify(viewport.mapToItem(bar, viewport.width, 0).x <= button.x, "the wider hit target does not cover bar content");
        mouseClick(button, 1, button.height / 2);
        verify(viewport.contentX > 0, "emergency overflow has an explicit pointer route");
        bar.controller.notificationActive = {notifications: [{urgency: 2}]};
        tryCompare(findChild(bar, "bar:notifications"), "foreground", Ui.Theme.danger);
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
