import QtQuick
import QtQuick.Layouts

// Passive explanation + a circular command. The row is never a hit target or
// field Tab stop; only the shared ActionButton owns activation/accessibility.
RowLayout {
    id: row
    property string label: ""
    property string accessibleName: label
    property alias icon: button.icon
    property alias accessKey: button.accessKey
    property alias commandScope: button.commandScope
    property alias toolTip: button.toolTip
    property alias tone: button.tone
    property alias uiScale: button.uiScale
    readonly property alias button: button
    signal clicked
    spacing: Theme.actionTitleGap

    ThemeText {
        Layout.fillWidth: true
        text: row.label
        wrapMode: Text.Wrap
    }
    ActionButton {
        id: button
        objectName: row.objectName + "Button"
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        sizeRole: "secondary"
        label: row.accessibleName
        onClicked: row.clicked()
    }
}
