pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane
    required property BatteryController controller
    objectName: "displayLayoutCard"
    title: qsTr("Display layout")
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
    property var draft: []
    property bool dirty: false
    property string previousTrial: ""
    property double clock: Date.now()
    readonly property var trial: (controller.displayPolicyState.layout || {}).trial || null
    readonly property bool interactive: controller.backend.ready && controller.displayPolicyState.available && !controller.actionInFlight && !trial

    function refresh(): void {
        draft = (controller.displayPolicyState.outputs || []).map(function (output) {
            return { name: output.name, mode: output.width + "x" + output.height + "@" + Number(output.refreshRate).toFixed(2),
                x: output.x || 0, y: output.y || 0, scale: output.scale, transform: output.transform || 0,
                enabled: /^(eDP-|LVDS-|DSI-)/.test(output.name) || !output.disabled,
                modes: output.availableModes || [] };
        });
        dirty = false;
    }
    function edit(index: int, key: string, value: var): void {
        // Do not rebuild delegates (and lose keyboard focus) while editing.
        draft[index][key] = value;
        dirty = true;
    }
    function preview(): void {
        const outputs = draft.map(function (value) {
            return { name: value.name, mode: value.mode, x: Number(value.x), y: Number(value.y),
                scale: Number(value.scale), transform: Number(value.transform), enabled: value.enabled };
        });
        controller.displayLayoutAction("preview", { outputs: outputs });
    }
    Component.onCompleted: refresh()
    Connections {
        target: pane.controller
        function onDisplayPolicyStateChanged(): void {
            const id = pane.trial ? pane.trial.id : "";
            if (!pane.dirty || (pane.previousTrial.length > 0 && id.length === 0))
                pane.refresh();
            pane.previousTrial = id;
        }
    }
    Timer {
        interval: 250
        repeat: true
        running: pane.visible && !!pane.trial
        onTriggered: pane.clock = Date.now()
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("Choose an advertised mode, scale, rotation and position. Changes revert after 20 seconds unless confirmed. Laptop fallback stays available during preview.")
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    Repeater {
        model: pane.draft
        delegate: ColumnLayout {
            id: outputRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            enabled: pane.interactive
            Ui.ThemeText { text: outputRow.modelData.name; font.weight: Ui.Theme.fontWeightBold }
            Controls.ComboBox {
                Layout.fillWidth: true
                model: outputRow.modelData.modes
                currentIndex: Math.max(0, model.indexOf(outputRow.modelData.mode + "Hz"))
                Accessible.name: outputRow.modelData.name + qsTr(" resolution and refresh rate")
                onActivated: pane.edit(outputRow.index, "mode", currentText)
            }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: ["x", "y", "scale"]
                    delegate: ColumnLayout {
                        id: field
                        required property string modelData
                        Layout.fillWidth: true
                        Ui.FieldLabel { text: field.modelData === "scale" ? qsTr("Scale") : field.modelData.toUpperCase() }
                        Ui.TextField {
                            Layout.fillWidth: true
                            text: String(outputRow.modelData[field.modelData])
                            maximumLength: 12
                            Accessible.name: outputRow.modelData.name + " " + field.modelData
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                            onEdited: function (value) { pane.edit(outputRow.index, field.modelData, value); }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Controls.ComboBox {
                    Layout.fillWidth: true
                    model: [qsTr("Normal"), qsTr("90°"), qsTr("180°"), qsTr("270°"), qsTr("Flipped"), qsTr("Flipped 90°"), qsTr("Flipped 180°"), qsTr("Flipped 270°")]
                    currentIndex: outputRow.modelData.transform
                    Accessible.name: outputRow.modelData.name + qsTr(" rotation")
                    onActivated: pane.edit(outputRow.index, "transform", currentIndex)
                }
                Controls.CheckBox {
                    text: qsTr("Enabled")
                    checked: outputRow.modelData.enabled
                    enabled: !/^(eDP-|LVDS-|DSI-)/.test(outputRow.modelData.name)
                    onToggled: pane.edit(outputRow.index, "enabled", checked)
                }
            }
        }
    }
    Ui.FieldLabel {
        Layout.fillWidth: true
        visible: !!pane.trial
        text: pane.trial ? qsTr("Keep this layout? Reverting in %1 seconds.").arg(Math.max(0, Math.ceil(pane.trial.expires_at - pane.clock / 1000))) : ""
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
    RowLayout {
        Layout.fillWidth: true
        Ui.ActionButton {
            objectName: "previewDisplayLayout"
            Layout.fillWidth: true
            label: qsTr("Preview layout")
            visible: !pane.trial
            enabled: pane.interactive && pane.dirty && pane.draft.length > 0
            onClicked: pane.preview()
        }
        Ui.ActionButton {
            Layout.fillWidth: true
            label: qsTr("Reload current")
            visible: !pane.trial
            enabled: pane.interactive
            onClicked: pane.refresh()
        }
        Ui.ActionButton {
            objectName: "confirmDisplayLayout"
            Layout.fillWidth: true
            label: qsTr("Keep layout")
            visible: !!pane.trial
            enabled: pane.controller.backend.ready && !pane.controller.actionInFlight
            onClicked: pane.controller.displayLayoutAction("confirm", { id: pane.trial.id })
        }
        Ui.ActionButton {
            objectName: "revertDisplayLayout"
            Layout.fillWidth: true
            label: qsTr("Revert")
            visible: !!pane.trial
            enabled: pane.controller.backend.ready && !pane.controller.actionInFlight
            onClicked: pane.controller.displayLayoutAction("revert", { id: pane.trial.id })
        }
    }
}
