import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ResultRow {
    id: row

    required property ClipboardController controller
    required property var resultData
    readonly property var entry: resultData.payload || ({})
    readonly property bool bulkSelected: !!controller.multiSelectedIds[entry.id]
    trailingActionWidth: scaled(40)
    primaryEnabled: !controller.multiSelectMode
    detailsActionVisible: !controller.multiSelectMode
    pickHandler: controller.multiSelectMode
        ? function (rowIndex) { controller.toggleEntrySelection(rowIndex); }
        : null

    Ui.GlyphLabel {
        Layout.preferredWidth: row.scaled(30)
        Layout.fillHeight: true
        glyph: row.resultData.icon
        color: row.entry.current ? Ui.Theme.active : Ui.Theme.accent
        font.pixelSize: Math.max(Ui.Theme.iconSize, row.scaled(Ui.Theme.fontSizeTitle))
    }

    Ui.ResultLabel {
        title: row.resultData.title
        titlePixelSize: Math.max(Ui.Theme.fontSizeSmall, row.scaled(Ui.Theme.fontSizeLabel))
        uiScale: row.uiScale
        singleLine: true
    }

    Ui.ThemeText {
        visible: row.entry.favorite
        Layout.preferredWidth: row.scaled(62)
        Layout.fillHeight: true
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignRight
        text: "Pinned"
        color: Ui.Theme.accent
        font.pixelSize: Math.max(9, row.scaled(Ui.Theme.fontSizeCaption))
        font.weight: Ui.Theme.fontWeightDemiBold
    }

    Rectangle {
        visible: row.controller.multiSelectMode
        z: 2
        Layout.preferredWidth: row.scaled(24)
        Layout.preferredHeight: row.scaled(24)
        radius: row.scaled(6)
        color: row.bulkSelected ? Ui.Theme.accent : "transparent"
        border.width: 1
        border.color: row.bulkSelected ? Ui.Theme.accent : Ui.Theme.strongBorder

        Ui.ThemeText {
            anchors.centerIn: parent
            text: "✓"
            visible: row.bulkSelected
            color: Ui.Theme.accentText
            font.pixelSize: Math.max(11, row.scaled(Ui.Theme.fontSizeBody))
            font.weight: Ui.Theme.fontWeightDemiBold
        }
    }

    Ui.DestructiveIconButton {
        visible: !row.controller.multiSelectMode
        z: 2
        Layout.preferredWidth: row.scaled(30)
        Layout.preferredHeight: row.scaled(30)
        enabled: !row.controller.actionInFlight
            && !row.controller.screenshotInFlight
            && !row.controller.wipeChallenge
        accessibleName: "Delete clipboard entry"
        toolTip: "Delete this clipboard entry"
        onClicked: {
            row.controller.select(row.index);
            row.controller.requestDelete();
        }
    }
}
