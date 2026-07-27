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

    Text {
        Layout.fillWidth: true
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        text: row.resultData.title
        color: Ui.Theme.text
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
        elide: Text.ElideRight
    }

    Text {
        visible: row.entry.favorite
        Layout.preferredWidth: row.scaled(62)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: "Pinned"
        color: Ui.Theme.accent
        font.family: Ui.Theme.fontFamily
        font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
        font.weight: Ui.Theme.fontWeightDemiBold
    }
}
