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
            todos: [], busy_dates: ["2026-03-29"], local_date: "2026-03-29",
            from_unix_ms: 0, to_unix_ms: 1,
            days: {"2026-03-29": {event_ids: ["native"], todo_ids: []}, "2026-03-30": {event_ids: [], todo_ids: []}}});
        const content = createTemporaryObject(contentFactory, testCase, {controller: owner, width: width, height: height});
        owner.openSection("schedule");
        tryVerify(() => findChild(content, "activityNextDay") !== null);
        compare(owner.selectedEvents.length, 1, "membership belongs to the daemon, not JS timestamps");
        mouseClick(findChild(content, "activityNextDay"));
        compare(owner.selectedDateKey, "2026-03-30");
        compare(owner.selectedEvents.length, 0);
        const previous = findChild(content, "activityPreviousDay");
        previous.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(owner.selectedEvents.length, 1);
        content.destroy();
        wait(0);
    }
}
