import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var application: resultData.payload || ({})

    leadingIcon: "󰀻"
    leadingIconSource: Quickshell.iconPath(resultData.icon || "application-x-executable", "application-x-executable")
    primaryActionId: resultData.primaryActionId || ""
    accessibleName: resultData.title + ". " + (resultData.subtitle || "")

    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle || ""
        titleWeight: row.application.focused ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }

    Ui.FlatIconButton {
        visible: row.application.running
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        icon: Presentation.runningWindowIcon(row.application.running_count)
        iconSize: Math.max(Ui.Theme.iconSizeSmall, row.scaled(Ui.Theme.iconSize))
        flatIconColor: row.application.focused ? Ui.Theme.active : Ui.Theme.accent
        enabled: !row.listPane.chooserController.actionInFlight
        accessibleName: "Focus " + row.resultData.title
        toolTip: "Focus “" + row.resultData.title + "”"
        onClicked: {
            row.listPane.chooserController.select(row.index);
            row.listPane.chooserController.primarySelected();
        }
    }

    Ui.DestructiveIconButton {
        visible: row.application.running
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        enabled: !row.listPane.chooserController.actionInFlight
        accessibleName: "Close " + row.resultData.title
        toolTip: "Close all running instances of “" + row.resultData.title + "”"
        onClicked: {
            row.listPane.chooserController.select(row.index);
            row.listPane.chooserController.triggerDetailAction("close");
        }
    }
}
