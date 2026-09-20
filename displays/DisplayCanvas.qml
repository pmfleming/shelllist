pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Rectangle {
    id: canvas
    required property DisplayController controller
    property bool editing: false
    readonly property var values: editing ? controller.draft : controller.outputs
    readonly property bool interactive: editing && controller.canEdit
    property var frozenBounds: null
    readonly property var extent: frozenBounds || Model.bounds(values)
    readonly property real factor: Math.max(0.001, Math.min(Math.max(1, width - 64) / extent.width, Math.max(1, height - 64) / extent.height))
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
    objectName: editing ? "displayWorkspaceCanvas" : "displayOverviewCanvas"
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.input
    border.color: activeFocus ? Ui.Theme.strongBorder : Ui.Theme.border
    clip: true
    activeFocusOnTab: true
    Accessible.role: Accessible.Pane
    Accessible.name: editing ? qsTr("Display arrangement") : qsTr("Current displays")
    Accessible.description: controller.selectedName + (editing ? qsTr(". Brackets select a display; arrows move it; Shift moves one pixel; Control moves 64 pixels.") : qsTr(". Enter opens the layout workspace."))

    function finishDrag(cancelled: bool): void {
        if (dragging && cancelled)
            controller.moveTo(dragName, dragX, dragY, 0);
        dragging = false;
        frozenBounds = null;
    }
    Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape && dragging) {
            finishDrag(true);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_BracketLeft || event.key === Qt.Key_BracketRight) {
            controller.cycleOutput(event.key === Qt.Key_BracketLeft ? -1 : 1);
            event.accepted = true;
            return;
        }
        if (!editing && [Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(event.key)) {
            if (!event.isAutoRepeat) controller.openDetails();
            event.accepted = true;
            return;
        }
        const delta = ({ [Qt.Key_Left]: [-1, 0], [Qt.Key_H]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_L]: [1, 0],
            [Qt.Key_Up]: [0, -1], [Qt.Key_K]: [0, -1], [Qt.Key_Down]: [0, 1], [Qt.Key_J]: [0, 1] })[event.key];
        if (editing && delta) {
            const step = event.modifiers & Qt.ShiftModifier ? 1 : event.modifiers & Qt.ControlModifier ? 64 : 16;
            controller.moveSelected(delta[0] * step, delta[1] * step);
            event.accepted = true;
        }
    }
    Repeater {
        // A count model keeps delegates and their pointer grabs alive while a draft changes.
        model: canvas.values.length
        delegate: Rectangle {
            id: screenRect
            required property int index
            readonly property var output: canvas.values[index] || ({})
            readonly property var geometry: Model.rect(output)
            readonly property bool selected: output.name === canvas.controller.selectedName
            readonly property bool outputEnabled: canvas.editing ? output.enabled : !output.disabled
            x: canvas.originX + geometry.x * canvas.factor
            y: canvas.originY + geometry.y * canvas.factor
            width: Math.max(8, geometry.width * canvas.factor)
            height: Math.max(8, geometry.height * canvas.factor)
            z: selected ? 1 : 0
            radius: 5
            color: selected ? Ui.Theme.selected : Ui.Theme.surfaceRaised
            border.width: selected ? 2 : 1
            border.color: selected ? Ui.Theme.accent : Ui.Theme.mutedText
            opacity: outputEnabled ? 1 : 0.5
            clip: true
            Accessible.role: Accessible.Button
            Accessible.name: (index + 1) + ". " + Model.title(output) + (outputEnabled ? qsTr(". On") : qsTr(". Off"))
            Accessible.selected: selected
            Accessible.onPressAction: canvas.controller.selectOutput(output.name)

            Rectangle {
                x: 6; y: 6; width: 24; height: 24; radius: 12
                color: screenRect.selected ? Ui.Theme.accent : Ui.Theme.border
                Ui.ThemeText {
                    anchors.centerIn: parent
                    text: screenRect.index + 1
                    font.weight: Ui.Theme.fontWeightBold
                    color: screenRect.selected ? Ui.Theme.accentText : Ui.Theme.text
                }
            }
            Ui.GlyphLabel {
                anchors.centerIn: parent
                glyph: screenRect.outputEnabled ? (Model.internal(screenRect.output.name) ? "󰌢" : "󰍹") : "󰶐"
                font.pixelSize: Math.min(32, screenRect.height / 3)
                color: screenRect.selected ? Ui.Theme.accent : Ui.Theme.mutedText
                visible: screenRect.height > 55
            }
            Ui.ThemeText {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                width: parent.width - 12
                x: 6
                horizontalAlignment: Text.AlignHCenter
                text: canvas.editing ? screenRect.output.name : Model.title(screenRect.output)
                elide: Text.ElideRight
                font.pixelSize: Ui.Theme.fontSizeSmall
                visible: screenRect.height > 95
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: canvas.interactive ? Qt.SizeAllCursor : Qt.PointingHandCursor
                onPressed: function (mouse) {
                    canvas.controller.selectOutput(screenRect.output.name);
                    canvas.forceActiveFocus();
                    if (!canvas.interactive) return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.frozenBounds = Model.bounds(canvas.values);
                    canvas.pressX = p.x; canvas.pressY = p.y;
                    canvas.dragX = screenRect.geometry.x; canvas.dragY = screenRect.geometry.y;
                    canvas.dragName = screenRect.output.name;
                    canvas.dragging = true;
                }
                onPositionChanged: function (mouse) {
                    if (!pressed || !canvas.dragging || !canvas.interactive) return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.controller.moveTo(canvas.dragName, canvas.dragX + (p.x - canvas.pressX) / canvas.factor,
                        canvas.dragY + (p.y - canvas.pressY) / canvas.factor, mouse.modifiers & Qt.AltModifier ? 0 : 10 / canvas.factor);
                }
                onReleased: canvas.finishDrag(false)
                onCanceled: canvas.finishDrag(true)
                onDoubleClicked: if (!canvas.editing) canvas.controller.openDetails()
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
