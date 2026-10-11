pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Snapshot/observed-total readings are passive. The label and value columns
// are measured once by the list, so a wide pane gives space to plots, not gaps.
RowLayout {
    id: reading
    required property var descriptor
    required property real labelWidth
    required property real valueSize
    property bool secondary: false
    readonly property string valueText: descriptor.valueText
    readonly property string accessibleLabel: descriptor.label
    readonly property string detailText: descriptor.detailText
    readonly property color accentColor: descriptor.color
    readonly property bool available: descriptor.available
    objectName: descriptor.objectName
    spacing: Ui.Theme.spacingSm
    Accessible.role: Accessible.StaticText
    Accessible.name: accessibleLabel + ": " + (available ? valueText : qsTr("Unavailable")) + ". " + detailText

    RowLayout {
        Layout.preferredWidth: reading.labelWidth
        Layout.minimumWidth: reading.labelWidth
        Layout.maximumWidth: reading.labelWidth
        spacing: Ui.Theme.spacingXs
        Item {
            Layout.preferredWidth: Ui.Theme.spacingSm
            Layout.preferredHeight: Ui.Theme.spacingXs
            // Energy is a total, never a second power series.
            visible: reading.descriptor.plotted !== false
            // Applications-owned legend stroke geometry, not a text/control
            // spacing override: solid vs two dashes also identifies the series.
            Row {
                anchors.centerIn: parent
                spacing: 2
                Repeater {
                    model: reading.secondary ? 2 : 1
                    Rectangle {
                        width: reading.secondary ? 3 : Ui.Theme.spacingSm
                        height: 2
                        color: reading.accentColor
                    }
                }
            }
            Accessible.ignored: true
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            text: reading.descriptor.shortLabel
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.metadataSize
            Accessible.ignored: true
        }
    }
    Ui.ThemeText {
        objectName: "resourceValue"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        text: reading.available ? reading.valueText : "—"
        color: reading.available ? reading.accentColor : Ui.Theme.mutedText
        horizontalAlignment: Text.AlignRight
        font.pixelSize: reading.valueSize
        font.weight: Ui.Theme.fontWeightMedium
        Accessible.ignored: true
    }
}
