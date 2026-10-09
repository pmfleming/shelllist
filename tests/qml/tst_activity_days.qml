import QtQuick
import Shelllist.Activity as Activity

DaemonTestCase {
    id: testCase
    name: "ActivityDays"
    when: windowShown
    width: 1200; height: 700; visible: true
    Component { id: ownerFactory; Activity.ActivityController {} }
    Component { id: contentFactory; Activity.ActivityContent {} }
    function test_dayCommandsUseNativeMembershipWithoutReclassifyingEvents() {
        const owner = createTemporaryObject(ownerFactory, testCase, {uiActive: true});
        owner.selectDate(new Date(2026, 2, 29));
        owner.applyRange({events: [{id: "native", title: "Native day", start_unix_ms: 0, end_unix_ms: 1}],
            todos: [{id: "native-todo", title: "A deliberately long translated task must wrap without shrinking its switch or its row", completed: false}], busy_dates: ["2026-03-29"], local_date: "2026-03-29",
            from_unix_ms: 0, to_unix_ms: 1,
            days: {"2026-03-29": {event_ids: ["native"], todo_ids: ["native-todo"]}, "2026-03-30": {event_ids: [], todo_ids: []}}});
        const content = createTemporaryObject(contentFactory, testCase, {controller: owner, width: width, height: height});
        owner.openSection("schedule");
        tryCompare(owner, "detailsExpansionProgress", 1);
        tryVerify(() => findChild(content, "activityNextDay") !== null);
        // The schedule Loader can expose the command before its first layout.
        const next = findChild(content, "activityNextDay");
        let loader = next.parent;
        while (loader && !(loader instanceof Loader)) loader = loader.parent;
        verify(loader !== null);
        tryCompare(loader, "status", Loader.Ready);
        tryVerify(() => next.visible && next.width > 0 && next.height > 0);
        verify(waitForPolish(testCase.Window.window));
        compare(owner.selectedEvents.length, 1, "membership belongs to the daemon, not JS timestamps");
        tryVerify(() => findChild(content, "todo::native-todo::completed") !== null);
        const todo = findChild(content, "todo::native-todo::completed");
        verify(waitForPolish(testCase.Window.window));
        verify(todo.height >= todo.implicitHeight, "a long task expands its row instead of clipping its label");
        compare(findChild(todo, "toggleTrack").width, 52);
        mouseClick(next);
        compare(owner.selectedDateKey, "2026-03-30");
        compare(owner.selectedEvents.length, 0);
        compare(owner.selectedTodos.length, 0);
        const previous = findChild(content, "activityPreviousDay");
        previous.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(owner.selectedEvents.length, 1);
        content.destroy();
        wait(0);
    }
}
