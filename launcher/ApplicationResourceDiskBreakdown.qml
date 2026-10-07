pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Ui.DetailColumnCard {
    id: breakdown
    required property var footprint
    required property real uiScale
    contentPadding: Math.round(12 * uiScale)
    verticalContentPadding: Math.round(12 * uiScale)
    contentSpacing: Math.round(10 * uiScale)
    readonly property real maximum: Math.max(1, footprint.reading.available ? footprint.total : 0,
        ...footprint.parts.map(part => part.available ? part.value : 0))
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Identified app-data breakdown. Scale 0 to %1.").arg(Resources.bytes(maximum))

    ApplicationResourceGlyph {
        glyph: "hard_drive"
        color: Ui.Theme.resourceDisk
        uiScale: breakdown.uiScale
    }
    Repeater {
        model: breakdown.footprint.parts
        delegate: ColumnLayout {
            id: part
            required property var modelData
            Layout.fillWidth: true
            spacing: Math.round(3 * breakdown.uiScale)
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label + ": " + modelData.valueText
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * breakdown.uiScale)
                ApplicationResourceGlyph {
                    glyph: part.modelData.icon
                    color: part.modelData.color
                    uiScale: breakdown.uiScale
                }
                ApplicationResourceBar {
                    objectName: "resourceBar_" + part.modelData.id
                    Layout.fillWidth: true
                    Layout.minimumWidth: 10 * breakdown.uiScale
                    fraction: part.modelData.available ? part.modelData.value / breakdown.maximum : 0
                    color: part.modelData.color
                    patterned: part.modelData.id === "temporary"
                    uiScale: breakdown.uiScale
                }
                Ui.ThemeText {
                    Layout.maximumWidth: breakdown.width * 0.4
                    text: part.modelData.available ? part.modelData.valueText : "—"
                    color: Ui.Theme.text
                    wrapMode: Text.Wrap
                    font.pixelSize: Ui.Theme.fontSizeSmall
                    Accessible.ignored: true
                }
            }
            Ui.ThemeText {
                visible: !part.modelData.available
                Layout.fillWidth: true
                text: qsTr("%1 unavailable").arg(part.modelData.label)
                color: Ui.Theme.mutedText
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }
    }
}
