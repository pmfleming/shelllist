import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

RowLayout {
    required property string label
    required property string value

    Layout.fillWidth: true
    Text { Layout.preferredWidth: 104; text: parent.label; color: Ui.Theme.subtleText; font.family: Ui.Theme.fontFamily; font.pixelSize: 11 }
    Text { Layout.fillWidth: true; text: parent.value || "Unavailable"; color: Ui.Theme.text; font.family: Ui.Theme.fontFamily; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
}
