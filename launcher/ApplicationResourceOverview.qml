pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Four equal snapshot cards. No card or reading joins editable traversal.
Ui.DetailSection {
    id: overview
    informationOnly: true
    required property var lanes
    required property var footprint
    required property real uiScale
    readonly property bool wide: width >= 620 * uiScale
    readonly property var cards: [
        {id: "activity", label: qsTr("Activity"), icon: "equalizer", color: Ui.Theme.resourceCpu, readings: lanes[0].series},
        {id: "memory", label: qsTr("Memory"), icon: "memory_alt", color: Ui.Theme.resourceMemory, readings: lanes[1].series},
        {id: "disk", label: qsTr("Disk"), icon: "hard_drive", color: Ui.Theme.resourceDisk, readings: [footprint.reading]},
        {id: "network", label: qsTr("Network"), icon: "lan", color: Ui.Theme.resourceNetworkReceive, readings: lanes[3].series}
    ]

    GridLayout {
        objectName: "applicationResourceCards"
        Layout.fillWidth: true
        columns: overview.wide ? 4 : 2
        columnSpacing: Math.round(8 * overview.uiScale)
        rowSpacing: columnSpacing
        Repeater {
            model: overview.cards
            delegate: Ui.DetailColumnCard {
                id: card
                required property var modelData
                objectName: "resourceCard_" + modelData.id
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                contentPadding: Math.round(12 * overview.uiScale)
                verticalContentPadding: Math.round(14 * overview.uiScale)
                contentSpacing: Math.round(12 * overview.uiScale)
                color: Ui.Theme.surfaceRaised

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Math.round(6 * overview.uiScale)
                    ApplicationResourceGlyph {
                        glyph: card.modelData.icon
                        color: card.modelData.color
                        uiScale: overview.uiScale * 0.85
                    }
                    Ui.ThemeText {
                        Layout.fillWidth: true
                        text: card.modelData.label
                        wrapMode: Text.Wrap
                        font.pixelSize: Ui.Theme.fontSizeSmall
                    }
                }
                Repeater {
                    model: card.modelData.readings
                    delegate: ApplicationResourceCapacity {
                        required property var modelData
                        required property int index
                        objectName: modelData.objectName
                        Layout.fillWidth: true
                        glyph: (card.modelData.id === "memory" || card.modelData.id === "disk") && index === 0 ? "" : modelData.icon
                        accessibleLabel: modelData.label
                        valueText: modelData.valueText
                        available: modelData.available
                        detailText: modelData.detailText
                        accentColor: modelData.color
                        uiScale: overview.uiScale
                        valueSize: (card.modelData.id === "disk" || card.modelData.id === "memory" && index === 0 ? 28
                            : card.modelData.id === "memory" ? 16 : 23) * overview.uiScale
                    }
                }
                GridLayout {
                    visible: card.modelData.id === "disk"
                    Layout.fillWidth: true
                    columns: width >= 120 * overview.uiScale ? 2 : 1
                    columnSpacing: Math.round(8 * overview.uiScale)
                    rowSpacing: Math.round(6 * overview.uiScale)
                    Repeater {
                        model: card.modelData.id === "disk" ? overview.lanes[2].series : []
                        delegate: ApplicationResourceCapacity {
                            required property var modelData
                            objectName: modelData.objectName
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            Layout.minimumWidth: 0
                            glyph: modelData.icon
                            accessibleLabel: modelData.label
                            valueText: modelData.valueText
                            available: modelData.available
                            detailText: modelData.detailText
                            accentColor: modelData.color
                            uiScale: overview.uiScale * 0.8
                            valueSize: 13 * overview.uiScale
                        }
                    }
                }
            }
        }
    }
}
