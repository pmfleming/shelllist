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

    Ui.ResultLabel {
        title: row.resultData.title
        subtitle: row.resultData.subtitle
        subtitleColor: Ui.Theme.mutedText
        uiScale: row.uiScale
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
