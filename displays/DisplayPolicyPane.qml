pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailCard {
    id: pane
    required property DisplayController controller
    objectName: "displayPolicyCard"
    implicitHeight: 66
    RowLayout {
        anchors.fill: parent
        spacing: Ui.Theme.spacingMd
        Ui.GlyphLabel { glyph: "󰌢"; color: (pane.controller.displayPolicyState.policy || {}).prefer_external ? Ui.Theme.disabledText : Ui.Theme.accent }
        Ui.GlyphLabel { glyph: "󰁔"; color: Ui.Theme.mutedText }
        Ui.GlyphLabel { glyph: "󰍹"; color: Ui.Theme.accent }
        Ui.ToggleRow {
            objectName: "preferExternalDisplay"
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: qsTr("Prefer external")
            subtitle: qsTr("Saved docking preference. Laptop returns if external displays disconnect.")
            showSubtitle: false
            checked: !!(pane.controller.displayPolicyState.policy || {}).prefer_external
            interactive: pane.controller.canSetPolicy
            onClicked: pane.controller.setPreferExternal(!checked)
        }
    }
}
