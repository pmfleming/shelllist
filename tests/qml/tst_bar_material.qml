pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Bar as Bar
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
    function init(): void { failOnWarning(/.*/); }
    function cleanup(): void { Tray.SystemTray.items.values = []; }
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
