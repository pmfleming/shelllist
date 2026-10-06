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

    property var toastGroups: [{records: [{actions: [
        {key: "default", label: "Open"},
        {key: "archive", label: "Archive"},
        {key: "reply", label: "Reply in app"},
        {key: "inline-reply", label: "Reply here"}
    ]}]}]
    component ToastGroup: Item {
        required property var modelData
    }
    Repeater {
        id: groupRepeater
        model: testCase.toastGroups
        delegate: ToastGroup {}
    }
    // Keep the native Repeater/array-like payload regression, not another
    // copy of shared action-menu focus or animation implementation tests.
    function test_actionsSurviveRepeaterModelData(): void {
        const group = groupRepeater.itemAt(0) as ToastGroup;
        verify(group !== null);
        const notification = group.modelData.records[0];
        compare(Ui.NotificationPresentation.standardActions(notification).map(action => action.key), ["archive", "reply"]);
        compare(Ui.NotificationPresentation.replyAction(notification).key, "inline-reply");
        compare(Ui.NotificationPresentation.defaultAction(notification).key, "default");
    }
}
