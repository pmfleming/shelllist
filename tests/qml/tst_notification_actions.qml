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
        id: quickActionsFactory
        Ui.NotificationQuickActions {
            showReply: true
        }
    }
    SignalSpy {
        id: quickSignal
        signalName: "replyRequested"
    }

    function test_quickActionsKeyboardPointerAndDisabledState(): void {
        const controls = createTemporaryObject(quickActionsFactory, this);
        quickSignal.target = controls;
        for (const action of ["Reply", "Snooze", "Dismiss"]) {
            const button = findChild(controls, "notificationQuick" + action);
            verify(button !== null);
            quickSignal.signalName = action.toLowerCase() + "Requested";
            quickSignal.clear();
            button.forceActiveFocus();
            verify(controls.activeFocusInside);
            keyClick(Qt.Key_Return);
            compare(quickSignal.count, 1);
            mouseClick(button);
            compare(quickSignal.count, 2);
            controls.enabled = false;
            keyClick(Qt.Key_Return);
            mouseClick(button);
            compare(quickSignal.count, 2);
            controls.enabled = true;
        }
        controls.showReply = false;
        verify(!findChild(controls, "notificationQuickReply").visible);
        tryCompare(controls, "implicitWidth", 66); // Hidden reply leaves no empty slot.
        testCase.forceActiveFocus();
        verify(!controls.activeFocusInside);
        quickSignal.target = null;
    }

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
                            key: "reply",
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
        compare(Ui.NotificationPresentation.replyAction(notification).key, "reply");
        compare(Ui.NotificationPresentation.defaultAction(notification).key, "default");
    }

}
