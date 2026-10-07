pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Snapshot readings are passive, never field stops. A missing metric is not zero.
ColumnLayout {
    id: reading

    required property string valueText
    property string label: ""
    property string glyph: ""
    property string accessibleLabel: label
    property string detailText: ""
    property color accentColor: Ui.Theme.resourceCpu
    property real uiScale: 1
    property real valueSize: 24 * uiScale
    property bool available: true
    property bool alignRight: glyph.length > 0
    property bool showUnavailable: true
    spacing: Math.round(3 * uiScale)
    Accessible.role: Accessible.StaticText
    Accessible.name: accessibleLabel + ": " + (available ? valueText : qsTr("Unavailable")) + ". " + detailText

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(6 * reading.uiScale)
        ApplicationResourceGlyph {
            objectName: "resourceGlyph"
            visible: reading.glyph.length > 0
            glyph: reading.glyph
            color: reading.accentColor
            uiScale: reading.uiScale
            Layout.alignment: Qt.AlignVCenter
        }
        Ui.ThemeText {
            objectName: "resourceValue"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: reading.available ? reading.valueText : "—"
            color: reading.available ? reading.accentColor : Ui.Theme.mutedText
            wrapMode: Text.Wrap
            horizontalAlignment: reading.alignRight ? Text.AlignRight : Text.AlignLeft
            font.pixelSize: reading.valueSize
            font.weight: Ui.Theme.fontWeightDemiBold
            Accessible.ignored: true
        }
    }
    Ui.ThemeText {
        objectName: "resourceUnavailable"
        Layout.fillWidth: true
        visible: !reading.available && reading.showUnavailable
        text: qsTr("%1 unavailable").arg(reading.accessibleLabel)
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
}
