pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui
import "DisplayModel.js" as Model

Rectangle {
    id: canvas
    required property DisplayController controller
    readonly property var allValues: controller.draft
    readonly property var values: Model.canvasValues(allValues)
    readonly property bool interactive: controller.canEdit && !controller.discardPrompt
    property var frozenBounds: null
    readonly property var extent: frozenBounds || Model.bounds(values)
    readonly property int captionSpace: dragging ? 24 : 0
    readonly property real factor: Math.max(0.001, Math.min(Math.max(1, width - 32) / extent.width, Math.max(1, height - 32 - captionSpace) / extent.height))
    readonly property real originX: (width - extent.width * factor) / 2 - extent.x * factor
    readonly property real originY: (height - captionSpace - extent.height * factor) / 2 - extent.y * factor
    property bool dragging: false
    property string armedName: ""
    property string dragName: ""
    property real pressX: 0
    property real pressY: 0
    property string dragSnapshot: ""
    property string observedSnapshot: ""
    property var targetEdge: null
    readonly property var candidate: dragging && targetEdge ? Model.placement(allValues, dragName, targetEdge.reference, targetEdge.side) : null
    readonly property string dragMessage: !dragging ? "" : !candidate ? qsTr("Drag %1 to another display’s edge · Escape cancels").arg(dragName) : candidate.error || qsTr("Place %1 %2 of %3").arg(dragName).arg(targetEdge.side).arg(targetEdge.reference)
    onDraggingChanged: controller.layoutDragging = dragging
    onInteractiveChanged: {
        if (!interactive)
            finishDrag(true);
    }
    onVisibleChanged: {
        if (!visible)
            finishDrag(true);
    }
    onWidthChanged: finishDrag(true)
    onHeightChanged: finishDrag(true)
    Component.onDestruction: controller.layoutDragging = false
    objectName: "displayArrangementSummary"
    radius: Ui.Theme.cardRadius
    color: Ui.Theme.input
    clip: true
    activeFocusOnTab: false
    Accessible.role: Accessible.Graphic
    Accessible.name: qsTr("Display layout")
    Accessible.description: allValues.map(o => qsTr("%1: %2, position %3, %4%5").arg(o.name).arg(o.enabled ? qsTr("on") : qsTr("off")).arg(o.x).arg(o.y).arg(o.mirror_of ? qsTr(", mirrors %1").arg(o.mirror_of) : "")).join("; ")

    function movePointer(x: real, y: real): void {
        if (!armedName || !interactive)
            return;
        if (!dragging) {
            if (Math.hypot(x - pressX, y - pressY) < 8)
                return;
            dragName = armedName;
            dragSnapshot = JSON.stringify(allValues);
            observedSnapshot = Model.fingerprint(controller.outputs);
            // Zoom out once at drag entry to make room for every snapped ghost,
            // then keep this transform stable until the gesture is finished.
            frozenBounds = Model.dragBounds(allValues, dragName);
            dragging = true;
        }
        targetEdge = x < 0 || x > width || y < 0 || y > height - 24 ? null : Model.dropTarget(allValues, dragName, (x - originX) / factor, (y - originY) / factor, 24 / factor, targetEdge, 6 / factor);
    }
    function finishDrag(cancelled: bool): void {
        const placement = !cancelled && dragging && candidate && !candidate.error ? candidate : null;
        const name = dragName;
        // Clear drag state before changing the draft: the same guard protects
        // both button actions and drops, and draft observers may cancel a drag.
        armedName = "";
        dragging = false;
        targetEdge = null;
        frozenBounds = null;
        dragName = "";
        if (placement)
            controller.placeDisplay(name, placement.reference, placement.side);
    }
    Connections {
        target: canvas.controller
        function onDraftChanged(): void {
            if (canvas.dragging && JSON.stringify(canvas.allValues) !== canvas.dragSnapshot)
                canvas.finishDrag(true);
        }
        function onOutputsChanged(): void {
            if (canvas.dragging && Model.fingerprint(canvas.controller.outputs) !== canvas.observedSnapshot)
                canvas.finishDrag(true);
        }
        function onUiActiveChanged(): void {
            if (!canvas.controller.uiActive)
                canvas.finishDrag(true);
        }
        function onSelectedNameChanged(): void {
            if (canvas.dragging && canvas.controller.selectedName !== canvas.dragName)
                canvas.finishDrag(true);
        }
    }
    Shortcut {
        sequence: "Escape"
        enabled: canvas.controller.uiActive && canvas.dragging
        onActivated: canvas.finishDrag(true)
    }
    Repeater {
        // Keep delegates and pointer grabs alive during selection and telemetry.
        model: canvas.values.length
        delegate: Rectangle {
            id: screenRect
            required property int index
            readonly property int outputNumber: canvas.controller.outputs.findIndex(o => o.name === output.name) + 1
            readonly property var output: canvas.values[index] || ({})
            readonly property var geometry: Model.rect(output)
            objectName: "displayMapScreen-" + output.name
            readonly property bool selected: output.name === canvas.controller.selectedName
            readonly property bool movable: canvas.interactive && Model.isIndependent(output) && Model.placementReferences(canvas.allValues, output.name).length > 0
            readonly property bool dropTarget: canvas.dragging && !!canvas.targetEdge && canvas.targetEdge.reference === output.name
            x: canvas.originX + geometry.x * canvas.factor
            y: canvas.originY + geometry.y * canvas.factor
            width: Math.max(8, geometry.width * canvas.factor)
            height: Math.max(8, geometry.height * canvas.factor)
            z: selected ? 1 : 0
            radius: 5
            color: selected ? Ui.Theme.selected : Ui.Theme.surfaceRaised
            border.width: selected || dropTarget ? 2 : 1
            border.color: dropTarget && canvas.candidate && canvas.candidate.error ? Ui.Theme.warning : selected || dropTarget ? Ui.Theme.accent : Ui.Theme.mutedText
            opacity: canvas.dragging && output.name === canvas.dragName ? 0.45 : output.enabled || selected ? 1 : 0.6
            clip: true
            Accessible.ignored: true

            Rectangle {
                x: 6
                y: 6
                width: 24
                height: 24
                radius: 12
                color: screenRect.selected ? Ui.Theme.accent : Ui.Theme.border
                visible: screenRect.height > 55 && screenRect.width > 32
                Ui.ThemeText {
                    anchors.centerIn: parent
                    text: screenRect.outputNumber
                    font.weight: Ui.Theme.fontWeightBold
                    color: screenRect.selected ? Ui.Theme.accentText : Ui.Theme.text
                }
            }
            Ui.GlyphLabel {
                anchors.centerIn: parent
                glyph: screenRect.output.enabled ? (screenRect.output.internal ? "󰌢" : "󰍹") : "󰶐"
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
                text: screenRect.output.name + (!screenRect.output.enabled ? qsTr(" · Off") : screenRect.output.mirror_of ? qsTr(" · Mirrors %1").arg(screenRect.output.mirror_of) : "")
                elide: Text.ElideRight
                font.pixelSize: Ui.Theme.fontSizeSmall
                visible: screenRect.height > 20
            }
            MouseArea {
                objectName: "displayMapPointer-" + screenRect.output.name
                anchors.fill: parent
                enabled: !canvas.controller.actionInFlight && !canvas.controller.trial && !canvas.controller.discardPrompt
                cursorShape: screenRect.movable ? Qt.SizeAllCursor : Qt.PointingHandCursor
                onEnabledChanged: {
                    if (!enabled && canvas.armedName === screenRect.output.name)
                        canvas.finishDrag(true);
                }
                onPressed: function (mouse) {
                    canvas.controller.selectOutput(screenRect.output.name);
                    if (!screenRect.movable)
                        return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.pressX = p.x;
                    canvas.pressY = p.y;
                    canvas.armedName = screenRect.output.name;
                }
                onPositionChanged: function (mouse) {
                    if (!pressed)
                        return;
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.movePointer(p.x, p.y);
                }
                onReleased: function (mouse) {
                    const p = mapToItem(canvas, mouse.x, mouse.y);
                    canvas.movePointer(p.x, p.y);
                    canvas.finishDrag(false);
                }
                onCanceled: canvas.finishDrag(true)
                onDoubleClicked: canvas.controller.openDetails()
            }
        }
    }
    Rectangle {
        objectName: "displayDropGhost"
        readonly property var geometry: canvas.candidate || ({ x: 0, y: 0, width: 0, height: 0 })
        visible: canvas.dragging && !!canvas.candidate && canvas.candidate.x !== undefined
        x: canvas.originX + geometry.x * canvas.factor
        y: canvas.originY + geometry.y * canvas.factor
        width: geometry.width * canvas.factor
        height: geometry.height * canvas.factor
        z: 2
        radius: 5
        color: Ui.Theme.withAlpha(canvas.candidate && canvas.candidate.error ? Ui.Theme.warning : Ui.Theme.accent, 0.18)
        border.width: 2
        border.color: canvas.candidate && canvas.candidate.error ? Ui.Theme.warning : Ui.Theme.accent
        Accessible.ignored: true
        Ui.ThemeText {
            anchors.centerIn: parent
            width: parent.width - 8
            text: canvas.dragName
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Ui.Theme.fontSizeSmall
        }
    }
    Ui.ThemeText {
        objectName: "displayDragStatus"
        x: 12
        y: canvas.height - height - 4
        width: canvas.width - 24
        z: 3
        text: canvas.dragMessage
        visible: canvas.dragging
        color: canvas.candidate && canvas.candidate.error ? Ui.Theme.warning : Ui.Theme.accent
        font.pixelSize: Ui.Theme.fontSizeSmall
        elide: Text.ElideRight
        Accessible.name: text
    }
    Ui.GlyphLabel {
        anchors.centerIn: parent
        visible: canvas.values.length === 0
        glyph: "󰶐"
        font.pixelSize: 48
        color: Ui.Theme.mutedText
    }
}
