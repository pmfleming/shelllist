pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

ColumnLayout {
    id: controls
    required property DisplayController controller
    readonly property var directions: [
        { side: "left", label: qsTr("← Left"), key: "L" },
        { side: "above", label: qsTr("↑ Above"), key: "U" },
        { side: "below", label: qsTr("↓ Below"), key: "D" },
        { side: "right", label: qsTr("→ Right"), key: "R" }
    ]
    readonly property string blockedDirections: controller.arrangementHint ? "" : directions.map(function (direction, index) {
        const error = controls.controller.placementChoices[index].error;
        return error ? direction.label + ": " + error : "";
    }).filter(Boolean).join(" · ")
    objectName: "displayArrangementControls"
    spacing: Ui.Theme.spacingSm

    function referenceLabel(name: string): string {
        const output = controller.outputs.find(o => o.name === name);
        return output && output.internal ? qsTr("Laptop (%1)").arg(name) : name;
    }

    Ui.FormField {
        Layout.fillWidth: true
        visible: !controls.controller.arrangementHint
        label: qsTr("Position relative to")
        Ui.ThemeText {
            Layout.fillWidth: true
            visible: controls.controller.placementReferences.length <= 1
            text: controls.referenceLabel(controls.controller.referenceName)
            font.pixelSize: Ui.Theme.formValueSize
        }
        Ui.DropDownList {
            objectName: "displayPositionReference"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            visible: controls.controller.placementReferences.length > 1
            interactive: controls.controller.canArrange
            options: controls.controller.placementReferences.map(o => ({ value: o.name, label: controls.referenceLabel(o.name) }))
            value: controls.controller.referenceName
            Accessible.name: qsTr("Position relative to display")
            onSelected: function (value) {
                if (controls.controller.canArrange && controls.controller.placementReferences.some(o => o.name === value))
                    controls.controller.referenceName = value;
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !controls.controller.arrangementHint
        spacing: Ui.Theme.spacingSm
        Item { Layout.fillWidth: true }
        Repeater {
            model: controls.directions
            delegate: Ui.ActionButton {
                required property var modelData
                required property int index
                readonly property string reason: controls.controller.placementChoices[index].error
                objectName: "displayPlace-" + modelData.side
                sizeRole: "secondary"
                icon: ({left: "arrow_back", above: "arrow_upward", below: "arrow_downward", right: "arrow_forward"})[modelData.side]
                label: modelData.label
                accessKey: modelData.key
                enabled: controls.controller.canArrange && !reason
                accessibleName: qsTr("Place %1 %2 of %3").arg(controls.controller.selectedName).arg(modelData.side).arg(controls.controller.referenceName)
                toolTip: reason || accessibleName
                onClicked: controls.controller.placeSelected(modelData.side)
            }
        }
    }
    Ui.FeedbackSource {
        objectName: "displayArrangementHint"
        text: controls.controller.arrangementHint || controls.blockedDirections || (controls.controller.canArrange && !controls.controller.dirty && !controls.controller.statusMessage ? qsTr("Drag to an edge or choose a direction") : "")
        summaryText: controls.blockedDirections ? qsTr("Some directions are blocked") : controls.controller.selectedDraft && !controls.controller.selectedDraft.enabled ? qsTr("Enable display to arrange or choose content") : controls.controller.selectedDraft && controls.controller.selectedDraft.mirror_of ? qsTr("Mirror follows source · Scaled to fit") : text
        tone: controls.blockedDirections ? "warning" : "info"
        priority: controls.blockedDirections ? 20 : 0
    }
}
