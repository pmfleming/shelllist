pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

ColumnLayout {
    id: overview
    required property DisplayController controller
    spacing: Ui.Theme.spacingMd
    DisplayCanvas {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(130, Math.min(220, overview.height * 0.4))
        controller: overview.controller
    }
    Ui.ScrollableListView {
        id: outputList
        objectName: "displayOutputList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: Ui.Theme.spacingXs
        model: overview.controller.outputs.length
        delegate: Ui.ActionButton {
            id: row
            required property int index
            readonly property var output: overview.controller.outputs[index] || ({})
            objectName: "displayOutput-" + output.name
            width: outputList.width
            height: Ui.Theme.listRowHeight
            backgroundColor: output.name === overview.controller.selectedName ? Ui.Theme.selected : "transparent"
            borderColor: "transparent"
            accessibleName: (index + 1) + ". " + Model.title(output) + (output.disabled ? qsTr(". Off") : qsTr(". On"))
            toolTip: output.name + " · " + output.width + " × " + output.height + " · " + Number(output.refreshRate).toFixed(2) + " Hz"
            onClicked: {
                overview.controller.selectOutput(output.name);
                overview.controller.openDetails();
            }
            RowLayout {
                anchors.fill: parent
                anchors.margins: Ui.Theme.spacingSm
                spacing: Ui.Theme.spacingMd
                Ui.ThemeText { text: row.index + 1; color: Ui.Theme.accent; font.weight: Ui.Theme.fontWeightBold }
                Ui.GlyphLabel { glyph: Model.internal(row.output.name) ? "󰌢" : "󰍹"; color: row.output.disabled ? Ui.Theme.disabledText : Ui.Theme.accent }
                Ui.ThemeText { Layout.fillWidth: true; text: Model.title(row.output); elide: Text.ElideRight }
                Ui.ThemeText { text: Math.round(Number(row.output.scale || 1) * 100) + "%"; color: Ui.Theme.mutedText; font.pixelSize: Ui.Theme.fontSizeSmall }
                Ui.GlyphLabel { glyph: row.output.disabled ? "󰶐" : "󰄬"; color: row.output.disabled ? Ui.Theme.disabledText : Ui.Theme.active }
                Ui.GlyphLabel { glyph: "󰅂"; color: Ui.Theme.mutedText }
            }
        }
    }
    DisplayPolicyPane {
        visible: overview.controller.hasInternal
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        controller: overview.controller
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Ui.ActionButton {
            Layout.preferredWidth: Ui.Theme.controlHeight
            icon: "󰈈"
            accessibleName: qsTr("Identify displays")
            toolTip: accessibleName
            enabled: overview.controller.activeCount > 0
            onClicked: overview.controller.identify()
        }
        Ui.ActionButton {
            id: arrange
            objectName: "arrangeDisplays"
            Layout.fillWidth: true
            icon: "󰍺"
            label: qsTr("Arrange")
            tone: "accent"
            enabled: overview.controller.outputs.length > 0
            onClicked: overview.controller.openDetails()
        }
    }
    Connections {
        target: overview.controller
        function onFocusSearchRequested(): void { arrange.forceActiveFocus(); }
        function onCompactFocusRequested(): void { arrange.forceActiveFocus(); }
    }
}
