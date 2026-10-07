pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "ApplicationResources.js" as Resources

Ui.DetailColumnCard {
    id: totals
    required property var lane
    required property bool loading
    required property real uiScale
    contentPadding: Math.round(12 * uiScale)
    verticalContentPadding: Math.round(12 * uiScale)
    contentSpacing: Math.round(10 * uiScale)
    readonly property real maximum: {
        const peak = Math.max(1, ...lane.series.map(descriptor => Resources.measured(descriptor.periodValue) ? descriptor.periodValue : 0));
        const step = Math.pow(10, Math.floor(Math.log(peak) / Math.LN10));
        return Math.ceil(peak / step) * step;
    }
    Accessible.role: Accessible.StaticText
    Accessible.name: lane.accessibleText + ". " + qsTr("Estimated transfer totals; scale 0 to %1.").arg(Resources.bytes(maximum))

    RowLayout {
        Layout.fillWidth: true
        ApplicationResourceGlyph { glyph: "lan"; color: Ui.Theme.resourceNetworkReceive; uiScale: totals.uiScale }
        Ui.ThemeText { Layout.fillWidth: true; text: qsTr("Network"); wrapMode: Text.Wrap; font.weight: Ui.Theme.fontWeightDemiBold }
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.ThemeText {
            Layout.fillWidth: true
            text: "0 – " + Resources.bytes(totals.maximum)
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
            wrapMode: Text.Wrap
        }
        Ui.ThemeText {
            text: qsTr("%1 totals").arg(totals.lane.rangeLabel)
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeCaption
        }
    }
    Repeater {
        model: totals.lane.series
        delegate: ColumnLayout {
            id: direction
            required property var modelData
            Layout.fillWidth: true
            readonly property bool available: !totals.loading && Resources.measured(modelData.periodValue)
            Accessible.role: Accessible.StaticText
            Accessible.name: modelData.label + ": " + (totals.loading ? qsTr("Loading") : modelData.periodText) + ". " + modelData.observation
            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * totals.uiScale)
                ApplicationResourceGlyph { glyph: direction.modelData.icon; color: direction.modelData.color; uiScale: totals.uiScale * 0.8 }
                ApplicationResourceBar {
                    objectName: "resourceTransferBar_" + direction.modelData.metric
                    Layout.fillWidth: true
                    Layout.minimumWidth: 10 * totals.uiScale
                    fraction: direction.available ? direction.modelData.periodValue / totals.maximum : 0
                    color: direction.modelData.color
                    patterned: direction.modelData.direction < 0
                    uiScale: totals.uiScale
                }
                Ui.ThemeText {
                    objectName: "resourceTransferValue_" + direction.modelData.metric
                    Layout.maximumWidth: totals.width * 0.55
                    text: totals.loading ? qsTr("Loading…") : direction.available ? direction.modelData.periodText : "—"
                    wrapMode: Text.Wrap
                    color: direction.modelData.color
                    font.pixelSize: 16 * totals.uiScale
                }
            }
            Ui.ThemeText {
                visible: !totals.loading && !direction.available
                Layout.fillWidth: true
                text: qsTr("%1 total unavailable").arg(direction.modelData.label)
                wrapMode: Text.Wrap
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeCaption
            }
        }
    }
    Ui.ThemeText {
        objectName: "resourceCoverage_network"
        Layout.fillWidth: true
        visible: !totals.loading
        text: "◷ " + totals.lane.coverageText
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
        wrapMode: Text.Wrap
    }
}
