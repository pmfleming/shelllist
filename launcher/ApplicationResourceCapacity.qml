pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Snapshot readings are passive, never field stops. A missing metric is not zero.
ColumnLayout {
    id: reading

    required property var descriptor
    readonly property string valueText: descriptor.valueText
    readonly property string accessibleLabel: descriptor.label
    readonly property string detailText: descriptor.detailText
    readonly property color accentColor: descriptor.color
    readonly property bool available: descriptor.available
    property string glyph: descriptor.icon
    property real uiScale: 1
    property real valueSize: 24 * uiScale
    property bool alignRight: glyph.length > 0
    property bool showUnavailableReason: true
    property bool overChart: false
    property bool fitToSlot: false
    property real glyphSize: 20 * uiScale
    objectName: descriptor.objectName
    spacing: Math.round(3 * uiScale)
    Accessible.role: Accessible.StaticText
    Accessible.name: accessibleLabel + ": " + (available ? valueText : qsTr("Unavailable")) + ". " + detailText

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: reading.fitToSlot
        Layout.minimumHeight: 0
        spacing: Math.round(6 * reading.uiScale)
        ApplicationResourceGlyph {
            objectName: "resourceGlyph"
            visible: reading.glyph.length > 0
            glyph: reading.glyph
            color: reading.accentColor
            uiScale: reading.glyphSize / 20
            Layout.alignment: Qt.AlignVCenter
        }
        Ui.ThemeText {
            objectName: "resourceValue"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.fillHeight: reading.fitToSlot
            Layout.minimumHeight: 0
            text: reading.available ? reading.valueText : "—"
            color: reading.available ? reading.accentColor : Ui.Theme.mutedText
            style: reading.overChart ? Text.Outline : Text.Normal
            styleColor: Ui.Theme.surfaceRaised
            wrapMode: reading.fitToSlot ? Text.NoWrap : Text.Wrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: reading.alignRight ? Text.AlignRight : Text.AlignLeft
            fontSizeMode: reading.fitToSlot ? Text.Fit : Text.FixedSize
            font.pixelSize: Math.max(Ui.Theme.resourceValueMinimumSize, reading.valueSize)
            minimumPixelSize: Ui.Theme.resourceValueMinimumSize
            font.weight: Ui.Theme.fontWeightDemiBold
            Accessible.ignored: true
        }
    }
    Ui.ThemeText {
        objectName: "resourceUnavailable"
        Layout.fillWidth: true
        visible: !reading.available && reading.showUnavailableReason
        text: qsTr("%1 unavailable").arg(reading.accessibleLabel)
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.metadataSize
        wrapMode: Text.Wrap
        Accessible.ignored: true
    }
}
