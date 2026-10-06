import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var application: resultData.payload || ({})
    readonly property int windowCount: (application.instances || []).length
    readonly property ApplicationController applicationController: listPane.chooserController as ApplicationController
    readonly property bool commandsEnabled: applicationController && !applicationController.operationBlocked && !applicationController.operations.busy(application.id)

    leadingIcon: "󰀻"
    leadingIconSource: Quickshell.iconPath(resultData.icon || "application-x-executable", "application-x-executable")
    accessibleName: resultData.title + ". " + (resultData.subtitle || "")

    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle || ""
        titleWeight: row.application.focused ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        uiScale: row.uiScale
    }

    Ui.FlatIconButton {
        objectName: "applicationFocus-" + row.application.id
        visible: row.windowCount > 0
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        icon: Presentation.runningWindowIcon(row.application.running_count)
        iconSize: Math.max(Ui.Theme.iconSizeSmall, row.scaled(Ui.Theme.iconSize))
        flatIconColor: row.application.focused ? Ui.Theme.active : Ui.Theme.accent
        enabled: row.commandsEnabled
        accessibleName: "Focus " + row.resultData.title
        toolTip: "Focus “" + row.resultData.title + "”"
        onClicked: {
            row.listPane.chooserController.select(row.index);
            row.listPane.chooserController.primarySelected();
        }
    }

    Ui.DestructiveIconButton {
        objectName: "applicationClose-" + row.application.id
        visible: row.windowCount > 0
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        enabled: row.commandsEnabled
        accessibleName: "Close all windows (" + row.windowCount + ") of " + row.resultData.title
        toolTip: accessibleName
        onClicked: {
            row.listPane.chooserController.select(row.index);
            row.listPane.chooserController.triggerDetailAction("close");
        }
    }
}
