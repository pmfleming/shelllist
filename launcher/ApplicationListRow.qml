import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var application: resultData.payload || ({})
    trailingActionWidth: application.running ? scaled(80) : 0

    Item {
        Layout.preferredWidth: row.scaled(34)
        Layout.preferredHeight: row.scaled(34)

        Image {
            id: applicationIcon
            anchors.fill: parent
            source: Quickshell.iconPath(row.resultData.icon || "application-x-executable", "application-x-executable")
            sourceSize.width: width
            sourceSize.height: height
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        Text {
            anchors.fill: parent
            visible: applicationIcon.status === Image.Error
            text: "󰀻"
            color: Ui.Theme.accent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            font.family: Ui.Theme.iconFontFamily
            font.pixelSize: row.scaled(Ui.Theme.iconSize)
        }
    }

    Text {
        Layout.fillWidth: true
        text: row.resultData.title
        color: Ui.Theme.text
        verticalAlignment: Text.AlignVCenter
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
        font.weight: row.application.focused ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
        elide: Text.ElideRight
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
