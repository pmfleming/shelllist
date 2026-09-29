pragma ComponentBehavior: Bound
import QtQuick
import QtTest
import Shelllist.Bar as Bar
import Shelllist.Ui as Ui
import "../../qml/Shelllist/Bar/BarMediaPresentation.js" as Media

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
    function test_groupsStayOrderedAndNumericalDataStaysInDetails_data() {
        return [{tag: "normal", width: 1200}, {tag: "compact", width: 700}, {tag: "emergency", width: 300}];
    }
    function test_groupsStayOrderedAndNumericalDataStaysInDetails(data): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: data.width});
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
        if (data.width === 300) {
            verify(bar.overflow);
            const viewport = findChild(bar, "barOverflowViewport");
            const button = findChild(bar, "barOverflowButton");
            mouseClick(button, button.width / 2, button.height / 2);
            verify(viewport.contentX > 0, "emergency overflow has an explicit pointer route");
        }
        bar.controller.notificationActive = {notifications: [{urgency: 2}]};
        tryCompare(findChild(bar, "bar:notifications"), "foreground", Ui.Theme.danger);
    }
    function test_unknownRoutesCannotCallObjectPrototypeMethods(): void {
        const bar = createTemporaryObject(barFactory, testCase, {width: 700});
        for (const name of ["missing", "__proto__", "constructor", "toString"])
            verify(!bar.controller.triggerModuleAction(name));
    }
    function test_transportModesNeverInventCapabilities(): void {
        const p = {can_control: true, can_seek: true, can_play: true, can_pause: false, playback_status: "playing"};
        verify(!Media.canPlayPause(p));
        compare(Media.transportAction(p, false).offset, -30);
        compare(Media.transportAction(p, true).offset, 30);
        verify(!Media.transportAction(Object.assign({}, p, {content_type: "music"}), true).enabled);
        verify(Media.transportAction(Object.assign({}, p, {content_type: "podcast"}), true).enabled);
        verify(!Media.transportAction(Object.assign({}, p, {can_control: false}), true).enabled);
    }
}
