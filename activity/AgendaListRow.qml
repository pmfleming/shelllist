import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ResultRow {
    id: row
    required property var resultData
    readonly property var item: resultData.payload
    readonly property AgendaController controller: listPane.chooserController as AgendaController
    readonly property string scheduleLabel: {
        const schedule = item.schedule;
        const timed = schedule.mode === "timed";
        const start = timed ? (item.schedule_text?.start_text || (schedule.start_unix_ms === null ? "" : new Date(schedule.start_unix_ms).toISOString())) : schedule.start_date;
        const end = timed ? (item.schedule_text?.end_text || (schedule.end_unix_ms === null ? "" : new Date(schedule.end_unix_ms).toISOString())) : schedule.end_date;
        if (!start && !end) return qsTr("No dates");
        return [start ? qsTr("Start %1").arg(start) : "", end ? qsTr("End / due %1").arg(end) : "", timed && schedule.timezone ? qsTr("Zone %1").arg(schedule.timezone) : ""].filter(Boolean).join(" · ");
    }
    objectName: "agendaRow::" + item.id
    accessibleName: item.title + ". " + scheduleLabel + (item.task?.completed ? qsTr(". Completed") : "")
    leadingIcon: item.kind === "task" ? (item.task.completed ? "check" : "checklist") : "calendar_month"
    primaryEnabled: item.kind === "event" || controller.canComplete(item)
    Ui.ResultLabel {
        Layout.fillWidth: true
        title: row.item.title
        subtitle: row.scheduleLabel + (row.item.task?.completed ? qsTr(" · Completed") : "")
    }
    Ui.FlatIconButton {
        visible: row.item.kind === "task"
        enabled: row.controller.canComplete(row.item)
        icon: row.item.task?.completed ? "restore" : "check"
        accessibleName: row.item.task?.completed ? qsTr("Reopen task") : qsTr("Complete task")
        onClicked: row.controller.complete(row.item)
    }
}
