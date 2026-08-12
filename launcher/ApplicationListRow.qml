import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationPresentation.js" as Presentation

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var application: resultData.payload || ({})

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

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 0

        Text {
            Layout.fillWidth: true
            text: row.resultData.title
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
            font.weight: row.application.focused ? Ui.Theme.fontWeightDemiBold : Ui.Theme.fontWeightRegular
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: row.application.running
                ? Presentation.usageText(row.application)
                : row.resultData.subtitle
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
            elide: Text.ElideRight
        }
    }

    Text {
        visible: row.application.running
        Layout.preferredWidth: row.scaled(30)
        text: Presentation.runningWindowIcon(row.application.running_count)
        color: row.application.focused ? Ui.Theme.active : Ui.Theme.accent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.family: Ui.Theme.iconFontFamily
        font.pixelSize: Math.max(Ui.Theme.iconSizeSmall, row.scaled(Ui.Theme.iconSize))
        Accessible.name: (row.application.running_count || 1) > 1
            ? String(row.application.running_count) + " running windows"
            : "Running window"
    }

    Ui.ActionButton {
        visible: row.application.running
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        label: ""
        icon: "󰅖"
        tone: "normal"
        backgroundColor: "transparent"
        borderColor: "transparent"
        labelColor: Ui.Theme.text
        hoverBackgroundColor: Ui.Theme.danger
        pressedBackgroundColor: Ui.Theme.mix(Ui.Theme.danger, Ui.Theme.dangerText, 0.14)
        enabled: !row.listPane.chooserController.actionInFlight
        accessibleName: "Close " + row.resultData.title
        toolTip: "Close all running instances of “" + row.resultData.title + "”"
        onClicked: {
            row.listPane.chooserController.select(row.index);
            row.listPane.chooserController.triggerDetailAction("close");
        }
    }
}
