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

    Component {
        id: menuFactory
        Ui.NotificationActionList {
            width: 320
            actions: [{key: "archive", label: "Archive conversation"}, {key: "mute", label: "Mute conversation"}]
            property string lastKey: ""
            onTriggered: function(key) { lastKey = key; }
        }
    }
    function test_namedActionsUseCircularMenuLauncher(): void {
        const actions = createTemporaryObject(menuFactory, testCase);
        const button = findChild(actions, "notificationAppActions");
        compare(button.width, button.height);
        compare(findChild(button, "actionLabel").label, "");
        button.forceActiveFocus();
        keyClick(Qt.Key_Return);
        const menu = findChild(actions, "notificationAppActionMenu");
        tryVerify(() => menu.activeFocus);
        compare(menu.count, 2);
        keyClick(Qt.Key_Down);
        keyClick(Qt.Key_Return);
        compare(actions.lastKey, "mute");
        tryVerify(() => button.activeFocus);
        keyClick(Qt.Key_Return);
        tryVerify(() => menu.activeFocus);
        keyClick(Qt.Key_Escape);
        tryVerify(() => button.activeFocus);
        compare(actions.lastKey, "mute", "Escape never invokes an action");
    }
    Component {
        id: removalFactory
        Rectangle {
            id: card
            width: 80; height: 40
            property bool removing: false
            property int completions: 0
            Ui.RemovalAnimation {
                targetItem: card
                removalRequested: card.removing
                onRemovalFinished: card.completions++
            }
        }
    }
    function test_removalSignalsCompletionOnce(): void {
        const card = createTemporaryObject(removalFactory, testCase);
        compare(card.completions, 0);
        card.removing = true;
        tryCompare(card, "completions", 1);
        compare(card.opacity, 0);
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
