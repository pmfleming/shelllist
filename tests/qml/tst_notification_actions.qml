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

    property var toastGroups: [
        {
            records: [
                {
                    actions: [
                        {
                            key: "default",
                            label: "Open"
                        },
                        {
                            key: "archive",
                            label: "Archive"
                        },
                        {
                            key: "inline-reply",
                            label: "Reply"
                        }
                    ]
                }
            ]
        }
    ]
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
        compare(Ui.NotificationPresentation.replyAction(notification).key, "inline-reply");
        compare(Ui.NotificationPresentation.defaultAction(notification).key, "default");
    }

}
