import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

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
            text: row.resultData.subtitle
            color: row.application.running ? Ui.Theme.accent : Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
            elide: Text.ElideRight
        }
    }

    Text {
        visible: row.application.running
        Layout.preferredWidth: row.scaled(46)
        text: row.application.focused ? "Active" : String(row.application.running_count || 1)
        color: row.application.focused ? Ui.Theme.active : Ui.Theme.accent
        horizontalAlignment: Text.AlignRight
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
        font.weight: Ui.Theme.fontWeightDemiBold
    }
}
