import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    name: "NotificationActions"
    when: windowShown
    visible: true
    width: 400
    height: 200

    Component {
        id: actionFactory
        Ui.NotificationActionList {
            width: 240
            actions: []
        }
    }
    SignalSpy {
        id: triggered
        signalName: "triggered"
    }

    function test_actionClassification(): void {
        const open = {
            key: "open",
            label: "Open"
        };
        const reply = {
            key: "inline-REPLY",
            label: "Reply"
        };
        const activate = {
            key: "default",
            label: "View"
        };
        const notification = {
            actions: [activate, open, reply]
        };
        compare(Ui.NotificationPresentation.standardActions(notification), [open]);
        verify(Ui.NotificationPresentation.replyAction(notification) === reply);
        verify(Ui.NotificationPresentation.defaultAction(notification) === activate);
        compare(Ui.NotificationPresentation.defaultAction({
            actions: [open]
        }), null);
        compare(Ui.NotificationPresentation.standardActions({}), []);
        compare(Ui.NotificationPresentation.replyAction({
            actions: {}
        }), null);
    }

    property var toastGroups: [{
            records: [{
                    actions: [{
                            key: "default",
                            label: "Open"
                        }, {
                            key: "archive",
                            label: "Archive"
                        }, {
                            key: "reply",
                            label: "Reply"
                        }]
                }]
        }]
    Repeater {
        id: groupRepeater
        model: toastGroups
        Item {
            required property var modelData
        }
    }

    function test_actionsSurviveRepeaterModelData(): void {
        const notification = groupRepeater.itemAt(0).modelData.records[0];
        compare(Ui.NotificationPresentation.standardActions(notification).map(function (action) {
            return action.key;
        }), ["archive"]);
        compare(Ui.NotificationPresentation.replyAction(notification).key, "reply");
        compare(Ui.NotificationPresentation.defaultAction(notification).key, "default");
    }

    function test_compactTimeLabels(): void {
        const now = new Date(2026, 8, 23, 15, 30).getTime();
        const at = function (month, day, hour, minute) {
            return new Date(2026, month, day, hour, minute).getTime();
        };
        compare(Ui.NotificationPresentation.timeLabel(now - 20000, now), "now");
        compare(Ui.NotificationPresentation.timeLabel(now - 5 * 60000, now), "5m");
        compare(Ui.NotificationPresentation.timeLabel(at(8, 23, 9, 0), now), "6h");
        compare(Ui.NotificationPresentation.timeLabel(at(8, 22, 23, 50), now), "Yesterday");
        compare(Ui.NotificationPresentation.timeLabel(at(8, 20, 12, 0), now), "20 Sep");
        compare(Ui.NotificationPresentation.timeLabel(0, now), "");
    }

    function test_keyboardActivationAndNarrowLayout(): void {
        const list = createTemporaryObject(actionFactory, this, {
            actions: [
                {
                    key: "open",
                    label: "A very long notification action label"
                }
            ]
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

}
