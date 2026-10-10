pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Bar as Bar

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
    function init(): void { failOnWarning(/.*/); }
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
