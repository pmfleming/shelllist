pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "UpdatePresentation.js" as Presentation

Ui.DetailColumnCard {
    id: card
    required property UpdateController controller
    // journalctl counts entries, which can contain embedded newlines. Bound the
    // rendered tail as well as the byte-bounded reply; Copy keeps the raw reply.
    readonly property var rawLines: controller.selectedLog ? controller.selectedLog.replace(/\n$/, "").split("\n") : []
    property bool informationOnly: true
    objectName: "updateRunLog"
    title: qsTr("Run log")
    visible: controller.selectedLogLoading || controller.selectedLogQueued || !!controller.selectedLogRecord
    Ui.ThemeText {
        objectName: "updateLogSource"
        Layout.fillWidth: true
        text: Presentation.logSource(card.controller.selectedRun)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
    Ui.ThemeText {
        objectName: "updateRunLogText"
        Layout.fillWidth: true
        visible: !!text
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: card.controller.selectedLogLoading ? qsTr("Reading log…") : card.controller.selectedLogQueued ? qsTr("Waiting to read log…") : card.controller.selectedLogError
            || (!card.controller.selectedLog ? qsTr("No readable log entries for this run. Child-build output may be recorded separately.") : "")
    }
    Repeater {
        model: card.rawLines.slice(-100)
        Ui.ThemeText {
            required property string modelData
            required property int index
            objectName: "updateLogLine:" + index
            Layout.fillWidth: true
            text: modelData
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "monospace"
            color: Presentation.logTone(modelData) === "error" ? Ui.Theme.danger
                : Presentation.logTone(modelData) === "warning" ? Ui.Theme.warning : Ui.Theme.text
        }
    }
    Ui.ThemeText {
        objectName: "updateLogLimit"
        Layout.fillWidth: true
        visible: !!card.controller.selectedLogRecord && !card.controller.selectedLogError
        text: card.controller.selectedLogRecord && (card.controller.selectedLogRecord.truncated || card.rawLines.length > 100)
            ? qsTr("Log truncated; showing up to the last 100 lines (32 KiB limit).")
            : qsTr("Up to the last 100 lines (32 KiB limit).")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
    }
}
