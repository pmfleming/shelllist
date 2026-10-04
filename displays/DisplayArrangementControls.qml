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

    RowLayout {
        Layout.fillWidth: true
        visible: !controls.controller.arrangementHint
        spacing: Ui.Theme.spacingSm
        Ui.ThemeText {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
            text: controls.controller.placementReferences.length > 1 ? qsTr("Move %1 relative to").arg(controls.controller.selectedName) : qsTr("Move %1 relative to %2").arg(controls.controller.selectedName).arg(controls.referenceLabel(controls.controller.referenceName))
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
        Ui.DropDownList {
            objectName: "displayPositionReference"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 1
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
        spacing: Ui.Theme.spacingXs
        Repeater {
            model: controls.directions
            delegate: Ui.ActionButton {
                required property var modelData
                required property int index
                readonly property string reason: controls.controller.placementChoices[index].error
                objectName: "displayPlace-" + modelData.side
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                label: modelData.label
                accessKey: modelData.key
                enabled: controls.controller.canArrange && !reason
                accessibleName: qsTr("Place %1 %2 of %3").arg(controls.controller.selectedName).arg(modelData.side).arg(controls.controller.referenceName)
                toolTip: reason || accessibleName
                onClicked: controls.controller.placeSelected(modelData.side)
            }
        }
    }
    Ui.ThemeText {
        objectName: "displayArrangementHint"
        Layout.fillWidth: true
        visible: text.length > 0
        text: controls.controller.arrangementHint || controls.blockedDirections
        wrapMode: Text.Wrap
        color: controls.controller.arrangementHint ? Ui.Theme.mutedText : Ui.Theme.warning
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
}
