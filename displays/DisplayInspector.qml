pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

ColumnLayout {
    id: inspector
    required property DisplayController controller
    readonly property var output: controller.selectedOutput || ({ name: "", availableModes: [] })
    readonly property var draft: controller.selectedDraft || ({ mode: "", scale: 1, transform: 0, x: 0, y: 0, enabled: false })
    spacing: Ui.Theme.spacingMd
    enabled: controller.canEdit

    function focusFirstControl(): void { resolution.forceActiveFocus(); }

    Ui.DetailColumnCard {
        objectName: "displayModeCard"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: implicitHeight
        title: qsTr("Display settings")
        contentSpacing: Ui.Theme.spacingMd

        GridLayout {
            objectName: "displayModeFields"
            Layout.fillWidth: true
            columns: width >= 300 ? 2 : 1
            columnSpacing: Ui.Theme.spacingSm
            rowSpacing: Ui.Theme.spacingMd
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("Resolution") }
                Ui.DropDownList {
                    id: resolution
                    objectName: "displayResolution"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    options: Model.resolutions(inspector.output)
                    value: (Model.parseMode(inspector.draft.mode) || {}).size || ""
                    Accessible.name: qsTr("Resolution")
                    onSelected: function (value) {
                        const choices = Model.modes(inspector.output).filter(function (m) { return (Model.parseMode(m) || {}).size === value; });
                        const oldRate = (Model.parseMode(inspector.draft.mode) || {}).rate;
                        const choice = choices.find(function (m) { return Model.parseMode(m).rate === oldRate; }) || choices[0];
                        if (choice) inspector.controller.edit(inspector.output.name, "mode", choice);
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("Refresh rate") }
                Ui.DropDownList {
                    objectName: "displayRefreshRate"
                    Layout.fillWidth: true
                    options: Model.rates(inspector.output, inspector.draft.mode)
                    value: inspector.draft.mode
                    Accessible.name: qsTr("Refresh rate")
                    onSelected: function (value) { inspector.controller.edit(inspector.output.name, "mode", value); }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("Scale") }
                Ui.DropDownList {
                    objectName: "displayScale"
                    Layout.fillWidth: true
                    options: {
                        const values = [0.5, 0.75, 1, 1.25, 1.5, 1.6, 1.75, 2, 2.5, 3, 4];
                        const current = Number(inspector.draft.scale);
                        if (Number.isFinite(current) && !values.includes(current)) values.push(current);
                        return values.sort(function (a, b) { return a - b; }).map(function (v) { return { value: String(v), label: Math.round(v * 10000) / 100 + "%" }; });
                    }
                    value: String(inspector.draft.scale)
                    Accessible.name: qsTr("Scale")
                    onSelected: function (value) { inspector.controller.edit(inspector.output.name, "scale", Number(value)); }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("Rotation") }
                Ui.DropDownList {
                    objectName: "displayRotation"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    options: ["0°", "90°", "180°", "270°", "↔ 0°", "↔ 90°", "↔ 180°", "↔ 270°"].map(function (label, i) { return { value: String(i), label: label }; })
                    value: String(inspector.draft.transform)
                    Accessible.name: qsTr("Rotation and reflection")
                    onSelected: function (value) { inspector.controller.edit(inspector.output.name, "transform", Number(value)); }
                }
            }
        }
        Ui.ThemeText {
            objectName: "displayEnablementStatus"
            Layout.fillWidth: true
            text: Model.internal(inspector.output.name) ? qsTr("Laptop fallback is managed by the display-wide docking preference.") : (inspector.draft.enabled ? qsTr("Enabled in the draft") : qsTr("Disabled in the draft"))
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }

    Ui.DetailColumnCard {
        objectName: "displayPositionCard"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: implicitHeight
        title: qsTr("Position")
        contentSpacing: Ui.Theme.spacingMd

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("X · logical pixels") }
                Ui.TextField {
                    objectName: "displayX"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: String(inspector.draft.x)
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    maximumLength: 8
                    Accessible.name: qsTr("X position in logical pixels")
                    onEdited: function (value) { inspector.controller.edit(inspector.output.name, "x", value); }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel { text: qsTr("Y · logical pixels") }
                Ui.TextField {
                    objectName: "displayY"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: String(inspector.draft.y)
                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                    maximumLength: 8
                    Accessible.name: qsTr("Y position in logical pixels")
                    onEdited: function (value) { inspector.controller.edit(inspector.output.name, "y", value); }
                }
            }
        }
        ColumnLayout {
            visible: inspector.controller.outputs.length > 1
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            Ui.FieldLabel { text: qsTr("Position relative to") }
            Ui.DropDownList {
                objectName: "displayPositionReference"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                options: inspector.controller.outputs.filter(function (o) { return o.name !== inspector.output.name; }).map(function (o) { return { value: o.name, label: o.name }; })
                value: inspector.controller.referenceName
                Accessible.name: qsTr("Position relative to display")
                onSelected: function (value) { inspector.controller.referenceName = value; }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingXs
                Repeater {
                    model: [{ side: "left", icon: "󰁍" }, { side: "above", icon: "󰁝" }, { side: "below", icon: "󰁅" }, { side: "right", icon: "󰁔" }]
                    delegate: Ui.ActionButton {
                        required property var modelData
                        objectName: "displayPlace-" + modelData.side
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        icon: modelData.icon
                        accessibleName: qsTr("Place %1 of %2").arg(modelData.side).arg(inspector.controller.referenceName)
                        toolTip: accessibleName
                        onClicked: inspector.controller.placeSelected(modelData.side)
                    }
                }
            }
        }
    }
}
