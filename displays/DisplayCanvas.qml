pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Rectangle {
    id: canvas
    required property DisplayController controller
    readonly property var allValues: controller.draft
    // Mirrors share the source's desktop, not another movable workspace tile.
    readonly property var values: allValues.filter(o => !Model.mirrorSource(o, allValues))
    readonly property string selectedSource: Model.mirrorSource(allValues.find(o => o.name === controller.selectedName) || ({}), allValues)
    readonly property bool interactive: controller.canEdit && !controller.discardPrompt
    property var frozenBounds: null
    readonly property var extent: frozenBounds || Model.bounds(values)
    readonly property real factor: Math.max(0.001, Math.min(Math.max(1, width - 32) / extent.width, Math.max(1, height - 32) / extent.height))
    readonly property real originX: (width - extent.width * factor) / 2 - extent.x * factor
    readonly property real originY: (height - extent.height * factor) / 2 - extent.y * factor
    property bool dragging: false
    onDraggingChanged: controller.layoutDragging = dragging
    Component.onDestruction: controller.layoutDragging = false
    property string dragName: ""
    property real dragX: 0
    property real dragY: 0
    property real pressX: 0
    property real pressY: 0
    objectName: "displayArrangementSummary"
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.input
    clip: true
    activeFocusOnTab: false
    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Display layout")
    Accessible.description: allValues.map(o => qsTr("%1: %2, position %3, %4%5").arg(o.name).arg(o.enabled ? qsTr("on") : qsTr("off")).arg(o.x).arg(o.y).arg(o.mirror_of ? qsTr(", mirrors %1").arg(o.mirror_of) : "")).join("; ")

    function finishDrag(cancelled: bool): void {
        if (dragging && cancelled)
            controller.moveTo(dragName, dragX, dragY, 0);
        dragging = false;
        frozenBounds = null;
    }
    // Escape cancels a pointer drag without putting the graphic in the focus chain.
    Shortcut {
        sequence: "Escape"
        enabled: canvas.controller.uiActive && canvas.dragging
        onActivated: canvas.finishDrag(true)
    }
    Repeater {
        // A count model keeps delegates and their pointer grabs alive while a draft changes.
        model: canvas.values.length
        delegate: Rectangle {
            id: screenRect
            required property int index
            readonly property int outputNumber: canvas.controller.outputs.findIndex(o => o.name === output.name) + 1
            readonly property var output: canvas.values[index] || ({})
            readonly property var geometry: Model.rect(output)
            readonly property bool selected: output.name === canvas.controller.selectedName || output.name === canvas.selectedSource
            readonly property string copies: canvas.allValues.filter(o => Model.mirrorSource(o, canvas.allValues) === output.name && o.enabled !== false).map(o => o.name).join(", ")
            x: canvas.originX + geometry.x * canvas.factor
            y: canvas.originY + geometry.y * canvas.factor
            width: Math.max(8, geometry.width * canvas.factor)
            height: Math.max(8, geometry.height * canvas.factor)
            z: selected ? 1 : 0
            radius: 5
            color: selected ? Ui.Theme.selected : Ui.Theme.surfaceRaised
            border.width: selected ? 2 : 1
            border.color: selected ? Ui.Theme.accent : Ui.Theme.mutedText
            opacity: output.enabled ? 1 : 0.5
            clip: true
            Accessible.ignored: true

            Rectangle {
                x: 6
                y: 6
                width: 24
                height: 24
                radius: 12
                color: screenRect.selected ? Ui.Theme.accent : Ui.Theme.border
                Ui.ThemeText {
                    anchors.centerIn: parent
                    text: screenRect.outputNumber
                    font.weight: Ui.Theme.fontWeightBold
                    color: screenRect.selected ? Ui.Theme.accentText : Ui.Theme.text
                }
            }
            Ui.GlyphLabel {
                anchors.centerIn: parent
                glyph: screenRect.output.enabled ? (Model.internal(screenRect.output.name) ? "󰌢" : "󰍹") : "󰶐"
                font.pixelSize: Math.min(32, screenRect.height / 3)
                color: screenRect.selected ? Ui.Theme.accent : Ui.Theme.mutedText
                visible: screenRect.height > 75
            }
            Ui.ThemeText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width - 12
                x: 6
                horizontalAlignment: Text.AlignHCenter
                text: screenRect.output.name + (screenRect.copies ? " → " + screenRect.copies : "")
                elide: Text.ElideRight
                font.pixelSize: Ui.Theme.fontSizeSmall
                visible: screenRect.height > 95
            }
            MouseArea {
                objectName: "displayMapPointer-" + screenRect.output.name
                anchors.fill: parent
                enabled: !canvas.controller.actionInFlight && !canvas.controller.trial && !canvas.controller.discardPrompt
                cursorShape: canvas.interactive ? Qt.SizeAllCursor : Qt.PointingHandCursor
                onPressed: function (mouse) {
                    canvas.controller.selectOutput(screenRect.output.name);
                    if (!canvas.interactive)
                        return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.frozenBounds = Model.bounds(canvas.values);
                    canvas.pressX = p.x;
                    canvas.pressY = p.y;
                    canvas.dragX = screenRect.geometry.x;
                    canvas.dragY = screenRect.geometry.y;
                    canvas.dragName = screenRect.output.name;
                    canvas.dragging = true;
                }
                onPositionChanged: function (mouse) {
                    if (!pressed || !canvas.dragging || !canvas.interactive)
                        return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.controller.moveTo(canvas.dragName, canvas.dragX + (p.x - canvas.pressX) / canvas.factor, canvas.dragY + (p.y - canvas.pressY) / canvas.factor, mouse.modifiers & Qt.AltModifier ? 0 : 10 / canvas.factor);
                }
                onReleased: canvas.finishDrag(false)
                onCanceled: canvas.finishDrag(true)
                onDoubleClicked: canvas.controller.openDetails()
            }
        }
    }
    Ui.GlyphLabel {
        anchors.centerIn: parent
        visible: canvas.values.length === 0
        glyph: "󰶐"
        font.pixelSize: 48
        color: Ui.Theme.mutedText
    }
}
