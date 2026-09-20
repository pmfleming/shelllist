pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content
    required property DisplayController controller

    Ui.ChooserShortcuts {
        controller: content.controller
        refreshEnabled: !content.controller.actionInFlight
        onRefreshRequested: content.controller.refresh()
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.headerHeight
            Ui.GlyphLabel { glyph: "󰍹"; color: Ui.Theme.accent }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: qsTr("Displays")
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }
            Ui.FlatIconButton {
                icon: "󰑐"
                accessibleName: qsTr("Refresh displays")
                toolTip: accessibleName
                onClicked: content.controller.refresh()
            }
        }
        Ui.DetailFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Column {
                width: parent.width
                spacing: Ui.Theme.spacingMd
                DisplayPolicyPane { controller: content.controller }
                DisplayLayoutPane { controller: content.controller }
            }
        }
    }
}
