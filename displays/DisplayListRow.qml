import QtQuick
import Shelllist.Ui as Ui

Ui.ResultRow {
    id: row
    required property var resultData
    objectName: "displayRow-" + resultData.id
    accessibleName: resultData.title + ". " + resultData.subtitle
    primaryEnabled: false

    leadingIcon: resultData.icon || "󰍹"
    leadingIconColor: resultData.state.active ? Ui.Theme.active : Ui.Theme.mutedText
    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle
        titleWeight: row.resultData.state.active ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }
}
