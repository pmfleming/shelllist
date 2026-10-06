pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// A compact, read-only snapshot reading. No implied capacity denominator.
RowLayout {
    id: reading

    required property string label
    required property string valueText
    property string accessibleLabel: label
    property string detailText: ""
    property color accentColor: Ui.Theme.resourceCpu
    property real uiScale: 1
    property bool available: true

    spacing: Math.round(6 * uiScale)
    Accessible.role: Accessible.StaticText
    Accessible.name: accessibleLabel + ": " + (available ? valueText : qsTr("Unavailable")) + ". " + detailText

    Ui.ThemeText {
        Layout.preferredWidth: Math.round(32 * reading.uiScale)
        Layout.alignment: Qt.AlignVCenter
        text: reading.label
        visible: reading.label.length > 0
        color: Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        Accessible.ignored: true
    }
    Ui.ThemeText {
        objectName: "resourceValue"
        Layout.fillWidth: true
        text: reading.available ? reading.valueText : "—"
        color: reading.available ? reading.accentColor : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeHeading
        font.weight: Ui.Theme.fontWeightDemiBold
        Accessible.ignored: true
    }
}
