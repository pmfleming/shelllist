import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ResultRow {
    id: row

    required property var resultData
    readonly property var entry: resultData.payload || ({})

    Text {
        Layout.preferredWidth: row.scaled(30)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        text: row.resultData.icon
        color: row.entry.current ? Ui.Theme.active : Ui.Theme.accent
        font.family: Ui.Theme.iconFontFamily
        font.pixelSize: Math.max(Ui.Theme.iconSize, row.scaled(Ui.Theme.fontSizeTitle))
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Math.max(1, row.scaled(2))
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignBottom
            text: row.resultData.title
            color: Ui.Theme.text
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            Layout.fillHeight: true
            verticalAlignment: Text.AlignTop
            text: row.resultData.subtitle
            color: Ui.Theme.mutedText
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Math.max(10, row.scaled(Ui.Theme.fontSizeCaption))
            elide: Text.ElideRight
        }
    }

    Text {
        visible: row.entry.current || row.entry.favorite
        Layout.preferredWidth: row.scaled(62)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: row.entry.current ? "Current" : "Pinned"
        color: row.entry.current ? Ui.Theme.active : Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
        font.weight: Ui.Theme.fontWeightDemiBold
    }
}
