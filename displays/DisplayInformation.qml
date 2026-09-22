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
    readonly property var entries: [
        { label: qsTr("Connector"), value: output.name },
        { label: qsTr("Description"), value: output.description },
        { label: qsTr("Manufacturer"), value: output.make },
        { label: qsTr("Model"), value: output.model },
        { label: qsTr("Serial number"), value: output.serial },
        { label: qsTr("Output identifier"), value: output.id },
        { label: qsTr("State"), value: output.disabled ? qsTr("Disabled") : qsTr("Enabled") },
        { label: qsTr("Current mode"), value: output.width > 0 && output.height > 0 ? Model.currentMode(output) : null },
        { label: qsTr("Logical size"), value: output.width > 0 && output.height > 0 ? Math.round(geometry.width) + " × " + Math.round(geometry.height) : null },
        { label: qsTr("Scale"), value: output.scale > 0 ? Math.round(output.scale * 10000) / 100 + "%" : null },
        { label: qsTr("Position"), value: output.x !== undefined && output.y !== undefined ? output.x + ", " + output.y : null },
        { label: qsTr("Rotation / reflection"), value: output.transform !== undefined ? ["0°", "90°", "180°", "270°", "↔ 0°", "↔ 90°", "↔ 180°", "↔ 270°"][output.transform] : null }
    ].filter(function (entry) { return entry.value !== undefined && entry.value !== null && String(entry.value).length > 0; })

    GridLayout {
        width: page.width
        columns: width >= 440 ? 2 : 1
        columnSpacing: Ui.Theme.spacingLg
        rowSpacing: Ui.Theme.spacingMd
        Repeater {
            model: page.entries
            delegate: Ui.DetailField {
                required property var modelData
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                label: modelData.label
                value: String(modelData.value)
                Accessible.name: label + ": " + value
            }
        }
    }
}
