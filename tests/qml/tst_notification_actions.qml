import QtQuick
import QtTest
import Shelllist.Ui as Ui

TestCase {
    id: testCase
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
    component ToastGroup: Item {
        required property var modelData
    }
    Repeater {
        id: groupRepeater
        model: testCase.toastGroups
        delegate: ToastGroup {}
    }

    function test_actionsSurviveRepeaterModelData(): void {
        const group = groupRepeater.itemAt(0) as ToastGroup;
        verify(group !== null);
        const notification = group.modelData.records[0];
        compare(Ui.NotificationPresentation.standardActions(notification).map(function (action) {
            return action.key;
        }), ["archive"]);
        compare(Ui.NotificationPresentation.replyAction(notification).key, "reply");
        compare(Ui.NotificationPresentation.defaultAction(notification).key, "default");
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
