import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "NotificationActions"
    when: windowShown
    visible: true
    width: 400
    height: 200

    Component { id: actionFactory; Ui.NotificationActionList { width: 240; actions: [] } }
    Component { id: badgeFactory; Ui.GroupCountBadge { count: 1 } }
    SignalSpy { id: triggered; signalName: "triggered" }

    function test_actionClassification(): void {
        const open = { key: "open", label: "Open" };
        const reply = { key: "inline-REPLY", label: "Reply" };
        const notification = { actions: [open, reply] };
        compare(Ui.NotificationPresentation.standardActions(notification), [open]);
        verify(Ui.NotificationPresentation.replyAction(notification) === reply);
        compare(Ui.NotificationPresentation.standardActions({}), []);
        compare(Ui.NotificationPresentation.replyAction({ actions: {} }), null);
    }

    function test_keyboardActivationAndNarrowLayout(): void {
        const list = createTemporaryObject(actionFactory, this, {
            actions: [{ key: "open", label: "A very long notification action label" }]
        });
        const button = findChild(list, "notificationAction-open");
        verify(button !== null);
        triggered.target = list;
        triggered.clear();
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(triggered.count, 1);
        compare(triggered.signalArguments[0][0], "open");
        compare(button.accessibleName, "A very long notification action label");
        list.width = 35;
        compare(button.width, 35);
        list.enabled = false;
        keyClick(Qt.Key_Return);
        compare(triggered.count, 1);
        triggered.target = null;
    }

    function test_groupBadgeVisibility(): void {
        const badge = createTemporaryObject(badgeFactory, this);
        verify(!badge.visible);
        badge.count = 2;
        verify(badge.visible);
        compare(badge.children[0].text, "2");
        badge.count = 10;
        compare(badge.children[0].text, "9+");
    }
}
