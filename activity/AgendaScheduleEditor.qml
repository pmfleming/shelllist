pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Raw modal buffers only. agenda.schedule in Rust validates civil dates, RFC3339
// offsets, IANA zones and DST before the parent submits one compound mutation.
ColumnLayout {
    id: editor
    required property var schedule
    property var scheduleText: null
    property string mode: schedule.mode
    property string startText: endpoint(true)
    property string endText: endpoint(false)
    property string zoneText: schedule.timezone || ""
    readonly property bool timed: mode === "timed"
    property var originalText: null
    Component.onCompleted: originalText = {mode: mode, start_text: startText, end_text: endText}
    signal changed(var value)
    spacing: Ui.Theme.spacingSm
    function endpoint(start: bool): string {
        if (schedule.mode === "timed" && scheduleText) return String((start ? scheduleText.start_text : scheduleText.end_text) || "");
        const value = schedule.mode === "timed" ? (start ? schedule.start_unix_ms : schedule.end_unix_ms) : (start ? schedule.start_date : schedule.end_date);
        return value === null || value === undefined ? "" : schedule.mode === "timed" ? new Date(value).toISOString() : String(value);
    }
    function value(): var {
        return {mode: mode, start_text: startText, end_text: endText, timezone: timed ? zoneText : "",
            start_unchanged: originalText?.mode === mode && originalText.start_text === startText,
            end_unchanged: originalText?.mode === mode && originalText.end_text === endText};
    }
    function update(): void { changed(value()); }
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Mode")
        Ui.DropDownList {
            objectName: "agendaScheduleMode"
            Layout.fillWidth: true
            options: [{value: "date", label: qsTr("Date only / all day")}, {value: "timed", label: qsTr("Timed")}]
            value: editor.mode
            onSelected: function(value) {
                editor.startText = ""; editor.endText = ""; editor.mode = value; editor.update();
            }
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Start")
        supportingText: editor.timed ? qsTr("Optional ISO instant with explicit UTC offset") : qsTr("Optional YYYY-MM-DD; clear for no start")
        Ui.TextField {
            objectName: "agendaScheduleStart"
            Layout.fillWidth: true
            text: editor.startText
            placeholder: editor.timed ? "YYYY-MM-DDTHH:MM:SS+HH:MM" : "YYYY-MM-DD"
            onEdited: function(value) { editor.startText = value; editor.update(); }
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("End / due")
        supportingText: editor.timed ? qsTr("Optional ISO instant with explicit UTC offset") : qsTr("Optional inclusive YYYY-MM-DD; clear for no end")
        Ui.TextField {
            objectName: "agendaScheduleEnd"
            Layout.fillWidth: true
            text: editor.endText
            placeholder: editor.timed ? "YYYY-MM-DDTHH:MM:SS+HH:MM" : "YYYY-MM-DD"
            onEdited: function(value) { editor.endText = value; editor.update(); }
        }
    }
    Ui.FormField {
        Layout.fillWidth: true
        visible: editor.timed
        label: qsTr("Timezone")
        supportingText: qsTr("Original IANA timezone; each instant must include the matching chosen UTC offset")
        Ui.TextField {
            objectName: "agendaScheduleZone"
            Layout.fillWidth: true
            text: editor.zoneText
            onEdited: function(value) { editor.zoneText = value; editor.update(); }
        }
    }
}
