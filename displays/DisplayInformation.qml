pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Ui.DetailFlickable {
    id: page
    required property DisplayController controller
    objectName: "displayInformation"
    readonly property var output: controller.selectedOutput || ({})
    readonly property var geometry: Model.rect(output)
    readonly property var statusEntries: availableEntries([
        {
            label: qsTr("State"),
            value: output.disabled ? qsTr("Disabled") : qsTr("Enabled"),
            valueColor: output.disabled ? Ui.Theme.mutedText : Ui.Theme.active,
            valueBold: !output.disabled
        },
        {
            label: qsTr("Current mode"),
            value: output.width > 0 && output.height > 0 ? Model.currentMode(output) : null
        },
        {
            label: qsTr("Logical size"),
            value: output.width > 0 && output.height > 0 ? Math.round(geometry.width) + " × " + Math.round(geometry.height) : null
        },
        {
            label: qsTr("Scale"),
            value: output.scale > 0 ? Math.round(output.scale * 10000) / 100 + "%" : null
        },
        {
            label: qsTr("Position"),
            value: output.x !== undefined && output.y !== undefined ? output.x + ", " + output.y : null
        },
        {
            label: qsTr("Rotation / reflection"),
            value: output.transform !== undefined ? ["0°", "90°", "180°", "270°", "↔ 0°", "↔ 90°", "↔ 180°", "↔ 270°"][output.transform] : null
        }
    ])
    readonly property var identityEntries: availableEntries([
        {
            label: qsTr("Connector"),
            value: output.name
        },
        {
            label: qsTr("Description"),
            value: output.description
        },
        {
            label: qsTr("Manufacturer"),
            value: output.make
        },
        {
            label: qsTr("Model"),
            value: output.model
        },
        {
            label: qsTr("Serial number"),
            value: output.serial
        },
        {
            label: qsTr("Output identifier"),
            value: output.id
        }
    ])
    readonly property var entries: statusEntries.concat(identityEntries)

    function availableEntries(values: var): var {
        return values.filter(function (entry) {
            return entry.value !== undefined && entry.value !== null && String(entry.value).length > 0;
        });
    }

    Repeater {
        model: [
            {
                name: "displayStatusCard",
                title: qsTr("Display status"),
                entries: page.statusEntries
            },
            {
                name: "displayIdentityCard",
                title: qsTr("Display information"),
                entries: page.identityEntries
            }
        ]
        delegate: Ui.DetailColumnCard {
            id: card
            required property var modelData
            objectName: modelData.name
            title: modelData.title
            height: implicitHeight
            visible: modelData.entries.length > 0

            GridLayout {
                objectName: card.objectName + "Fields"
                Layout.fillWidth: true
                columns: width >= 360 ? 2 : 1
                columnSpacing: Ui.Theme.spacingLg
                rowSpacing: Ui.Theme.spacingMd
                Repeater {
                    model: card.modelData.entries
                    delegate: Ui.DetailField {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 1
                        label: modelData.label
                        value: String(modelData.value)
                        valueColor: modelData.valueColor || Ui.Theme.text
                        valueBold: !!modelData.valueBold
                        Accessible.name: label + ": " + value
                    }
                }
            }
        }
    }
}
