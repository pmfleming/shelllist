pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: heading
    property string title: ""
    property string helpText: ""
    property bool helpOpen: false
    spacing: Ui.Theme.spacingSm

    RowLayout {
        Layout.fillWidth: true
        Ui.ThemeText {
            Layout.fillWidth: true
            text: heading.title
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightDemiBold
            wrapMode: Text.Wrap
        }
        Ui.FlatIconButton {
            objectName: "batterySectionHelp"
            visible: heading.helpText.length > 0
            Layout.preferredWidth: Ui.Theme.formActionSize
            Layout.preferredHeight: Ui.Theme.formActionSize
            iconSize: Ui.Theme.formActionIconSize
            icon: heading.helpOpen ? "expand_less" : "help_outline"
            accessibleName: qsTr("Help: %1").arg(heading.title)
            Accessible.description: heading.helpText
            // Read-only group help is a named Alt+J command, never a Tab stop.
            onClicked: heading.helpOpen = !heading.helpOpen
        }
    }
    Ui.FieldLabel {
        Layout.fillWidth: true
        visible: heading.helpOpen
        text: heading.helpText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
