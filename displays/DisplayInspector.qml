pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

ColumnLayout {
    id: inspector
    required property DisplayController controller
    readonly property var output: controller.selectedOutput || ({
            name: "",
            modes: []
        })
    readonly property var draft: controller.selectedDraft || ({
            mode: "",
            scale: 1,
            transform: 0,
            x: 0,
            y: 0,
            enabled: false
        })
    spacing: Ui.Theme.spacingMd
    enabled: controller.canEdit

    function focusFirstControl(): void {
        resolution.forceActiveFocus();
    }

    Ui.DetailColumnCard {
        objectName: "displayContentCard"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: implicitHeight
        title: qsTr("Display content")
        contentSpacing: Ui.Theme.spacingSm
        Ui.DropDownList {
            objectName: "displayContentMode"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            options: [
                {
                    value: "",
                    label: qsTr("Extend desktop")
                }
            ].concat(Model.mirrorSources(inspector.controller.draft, inspector.output.name).map(function (source) {
                const output = inspector.controller.outputs.find(o => o.name === source.name) || source;
                return {
                    value: source.name,
                    label: qsTr("Mirror %1 (%2)").arg(Model.title(output)).arg(source.name)
                };
            }))
            value: inspector.draft.mirror_of || ""
            interactive: inspector.controller.canEdit && !!inspector.draft.enabled
            Accessible.name: qsTr("Extend desktop or mirror another display")
            onSelected: function (value) {
                inspector.controller.setDisplayContent(inspector.output.name, value);
            }
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            visible: text.length > 0
            text: !inspector.draft.enabled ? qsTr("Enable this display to choose its content.") : inspector.draft.mirror_of ? qsTr("Mirrors %1 · position follows the source. Scaled to fit; black bars may appear.").arg(inspector.draft.mirror_of) : ""
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
        Ui.ThemeText {
            Layout.fillWidth: true
            visible: inspector.controller.draft.some(o => o.enabled && o.mirror_of === inspector.output.name)
            text: qsTr("Copies must extend before this display can mirror another. Disabling it makes its copies extended displays.")
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }

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
                Ui.FieldLabel {
                    text: qsTr("Resolution")
                }
                Ui.DropDownList {
                    id: resolution
                    objectName: "displayResolution"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    options: Model.resolutions(inspector.output)
                    value: (Model.modeInfo(inspector.output, inspector.draft.mode) || {}).size || ""
                    Accessible.name: qsTr("Resolution")
                    onSelected: function (value) {
                        const choices = Model.modes(inspector.output).filter(function (m) {
                            return m.size === value;
                        });
                        const oldRate = (Model.modeInfo(inspector.output, inspector.draft.mode) || {}).rate;
                        const choice = choices.find(function (m) {
                            return m.rate === oldRate;
                        }) || choices[0];
                        if (choice)
                            inspector.controller.edit(inspector.output.name, "mode", choice.id);
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel {
                    text: qsTr("Refresh rate")
                }
                Ui.DropDownList {
                    objectName: "displayRefreshRate"
                    Layout.fillWidth: true
                    options: Model.rates(inspector.output, inspector.draft.mode)
                    value: inspector.draft.mode
                    Accessible.name: qsTr("Refresh rate")
                    onSelected: function (value) {
                        inspector.controller.edit(inspector.output.name, "mode", value);
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel {
                    text: qsTr("Scale")
                }
                Ui.DropDownList {
                    objectName: "displayScale"
                    Layout.fillWidth: true
                    options: {
                        const values = [0.5, 0.75, 1, 1.25, 1.5, 1.6, 1.75, 2, 2.5, 3, 4];
                        const current = Number(inspector.draft.scale);
                        if (Number.isFinite(current) && !values.includes(current))
                            values.push(current);
                        return values.sort(function (a, b) {
                            return a - b;
                        }).map(function (v) {
                            return {
                                value: String(v),
                                label: Math.round(v * 10000) / 100 + "%"
                            };
                        });
                    }
                    value: String(inspector.draft.scale)
                    Accessible.name: qsTr("Scale")
                    onSelected: function (value) {
                        inspector.controller.edit(inspector.output.name, "scale", Number(value));
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 1
                spacing: Ui.Theme.spacingXs
                Ui.FieldLabel {
                    text: qsTr("Rotation")
                }
                Ui.DropDownList {
                    objectName: "displayRotation"
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    options: ["0°", "90°", "180°", "270°", "↔ 0°", "↔ 90°", "↔ 180°", "↔ 270°"].map(function (label, i) {
                        return {
                            value: String(i),
                            label: label
                        };
                    })
                    value: String(inspector.draft.transform)
                    Accessible.name: qsTr("Rotation and reflection")
                    onSelected: function (value) {
                        inspector.controller.edit(inspector.output.name, "transform", Number(value));
                    }
                }
            }
        }
        Ui.ThemeText {
            objectName: "displayEnablementStatus"
            Layout.fillWidth: true
            text: inspector.draft.enabled ? qsTr("Enabled in the draft") : qsTr("Disabled in the draft")
            wrapMode: Text.Wrap
            color: Ui.Theme.mutedText
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }

    DisplayPolicyPane {
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        Layout.preferredHeight: implicitHeight
        visible: !!inspector.output.internal
        controller: inspector.controller
    }
}
