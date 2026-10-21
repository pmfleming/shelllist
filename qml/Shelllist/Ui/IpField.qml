pragma ComponentBehavior: Bound
import QtQuick
import "IpEdit.js" as IpEdit
import "IpValidation.js" as IpValidation

// One native selection surface and one transaction for either IP family. Slots
// are an edit model, never child TextFields or independent navigation targets.
FieldFrame {
    id: field

    property string text: ""
    property string family: "ipv4"
    property string mode: "address"
    property string subnetNotation: "prefix"
    property bool allowEmpty: false
    property string focusKey: objectName
    property string placeholder: ""
    property bool validationAttempted: false
    readonly property var configuration: ({family: family, mode: mode, subnetNotation: subnetNotation, allowEmpty: allowEmpty})
    readonly property var inspection: IpEdit.inspect(text, configuration)
    readonly property int validationState: inspection.state
    readonly property bool inputValid: validationState !== IpValidation.Invalid && (!validationAttempted || validationState === IpValidation.Acceptable)
    readonly property string invalidDescription: inputValid ? "" : mode === "addressWithSubnet"
        ? qsTr("Invalid value. Enter a complete %1 address and a valid subnet (%2). Scoped addresses and ports are not supported.").arg(family === "ipv6" ? "IPv6" : "IPv4").arg(family === "ipv6" ? qsTr("prefix 0–128") : qsTr("prefix 0–32 or a contiguous dotted mask"))
        : qsTr("Invalid value. Enter a complete %1 address without a subnet, scope suffix or port.").arg(family === "ipv6" ? "IPv6" : "IPv4")
    readonly property alias inputActiveFocus: input.activeFocus
    readonly property alias inputMethodComposing: input.inputMethodComposing
    readonly property alias cursorPosition: input.cursorPosition
    readonly property FieldEditSession editSession: FieldEditSession {
        owner: field
        available: field.enabled && !field.readOnly && IpEdit.supported(field.configuration)
        valueProperty: "text"
        initialValue: field.text
        value: field.inspection.valid ? field.inspection.text : field.text
        focused: field.inputActiveFocus
        onRestoreRequested: function (value) { field.text = value; }
        onPublishRequested: function (value) { field.edited(value); }
        onFinished: function (saved) {
            if (saved) {
                field.validationAttempted = true;
                field.editingFinished();
            }
        }
        onActiveChanged: {
            field.refreshView();
            field.history = [field.positionState];
            field.historyIndex = 0;
        }
        onAvailableChanged: if (!available) field.cancelEdit()
    }
    signal edited(string value)
    signal editingFinished
    signal selectionChanged

    implicitHeight: Theme.formHeight
    focused: input.activeFocus && !readOnly
    // Validation is text-only. Focus paint continues to mean browse/edit state.
    invalid: false
    hovered: hover.hovered

    property bool applying: false
    property bool pasting: false
    property bool backwardsDelete: true
    property var positionState: ({text: "", cursor: 0, anchor: 0, autoSlot: -1})
    property var history: []
    property int historyIndex: 0

    function cancelEdit(): void {
        if (editSession.active && !editSession.finishing) {
            if (editSession.navigation) {
                editSession.navigation.finishEditor(false);
                editSession.navigation.focusContent();
            } else editSession.finish(false);
        }
        validationAttempted = false;
        refreshView();
    }
    onFamilyChanged: cancelEdit()
    onModeChanged: cancelEdit()
    onSubnetNotationChanged: cancelEdit()
    onAllowEmptyChanged: cancelEdit()
    onTextChanged: if (!applying) refreshView()
    onValidationAttemptedChanged: if (!editSession.active) refreshView()
    Component.onCompleted: refreshView()

    function refreshView(): void {
        const emptyInvalid = validationAttempted && !inputValid && !text.length && !readOnly && enabled;
        const shown = editSession.active || emptyInvalid ? IpEdit.prepare(text, configuration) : text;
        const cursor = Math.min(input.cursorPosition, shown.length);
        setView({text: shown, cursor: cursor, anchor: cursor, autoSlot: -1}, false);
    }
    function setView(state: var, updateDraft: bool): void {
        applying = true;
        if (updateDraft) text = state.text;
        input.text = state.text;
        input.select(state.anchor, state.cursor);
        positionState = state;
        applying = false;
        selectionChanged();
    }
    function rememberSelection(): void {
        // Native text changes precede selection notifications; retain the old
        // selection until the complete edit operation has been accepted/rejected.
        if (applying || input.text !== positionState.text) return;
        positionState = {text: input.text, cursor: input.cursorPosition,
            anchor: input.cursorPosition === input.selectionStart ? input.selectionEnd : input.selectionStart,
            autoSlot: input.cursorPosition === positionState.cursor ? positionState.autoSlot : -1};
        selectionChanged();
    }
    function acceptOperation(next: var): void {
        if (!next) {
            setView(positionState, false);
            return;
        }
        if (next.text !== positionState.text) {
            const entries = history.slice(0, historyIndex + 1);
            entries[historyIndex] = positionState;
            entries.push(next);
            // Field-local undo only, bounded independently of the clipboard size.
            if (entries.length > 128) entries.shift();
            history = entries;
            historyIndex = entries.length - 1;
            setView(next, true);
        } else setView(next, false);
    }
    function undo(redo: bool): void {
        const index = historyIndex + (redo ? 1 : -1);
        if (index < 0 || index >= history.length) return;
        historyIndex = index;
        setView(history[index], true);
    }
    function focusInput(selectContents: bool): void {
        input.forceActiveFocus();
        if (selectContents) input.selectAll();
    }
    function selectionState(): var {
        return {cursor: input.cursorPosition, anchor: input.cursorPosition === input.selectionStart ? input.selectionEnd : input.selectionStart};
    }
    function restoreSelection(state: var): void {
        if (!state || !Number.isFinite(state.cursor) || !Number.isFinite(state.anchor)) return;
        input.select(Math.max(0, Math.min(state.anchor, input.text.length)), Math.max(0, Math.min(state.cursor, input.text.length)));
    }
    function handleKey(event: var): void {
        editSession.handleKey(event);
        if (event.accepted || !editSession.available) return;
        const control = !!(event.modifiers & (Qt.ControlModifier | Qt.MetaModifier));
        const shift = !!(event.modifiers & Qt.ShiftModifier);
        if (control && (event.key === Qt.Key_Z || event.key === Qt.Key_Y)) {
            undo(event.key === Qt.Key_Y || shift);
        } else if ((control && event.key === Qt.Key_V) || (shift && event.key === Qt.Key_Insert)) {
            // Native paste reads the whole clipboard. Its buffer is deliberately
            // not a short IP maxLength, so no clipped suffix can become valid.
            pasting = true;
            input.paste();
            pasting = false;
        } else if (!control && !(event.modifiers & Qt.AltModifier)
                && (event.text === "/" || (event.text === "." && family === "ipv4"))) {
            acceptOperation(IpEdit.separator(positionState, configuration, event.text));
        } else {
            backwardsDelete = event.key !== Qt.Key_Delete;
            return;
        }
        event.accepted = true;
    }

    HoverHandler { id: hover; enabled: field.enabled }
    TextInput {
        id: input
        objectName: "ipFieldInput"
        anchors.fill: parent
        clip: true
        leftPadding: Theme.formPadding
        rightPadding: Theme.formPadding + (stateBadge.visible ? stateBadge.width + Theme.spacingSm : 0)
        selectByMouse: true
        readOnly: field.readOnly
        // Never accept a truncated native operation. The edit model bounds and
        // rejects its complete payload; raw source validation is independently bounded.
        maximumLength: 2147483647
        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        color: field.inputValid ? Theme.inputText : Theme.danger
        selectionColor: field.inputValid ? Theme.accent : Theme.dangerBackground
        selectedTextColor: field.inputValid ? Theme.accentText : Theme.danger
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.formValueSize
        verticalAlignment: TextInput.AlignVCenter
        Accessible.name: field.Accessible.name || (field.family === "ipv6" ? "IPv6" : "IPv4")
        Accessible.description: [field.Accessible.description,
            field.mode === "addressWithSubnet" ? qsTr("Address and subnet; one field") : qsTr("Address only"),
            field.allowEmpty ? qsTr("Optional") : qsTr("Required"), field.invalidDescription,
            field.readOnly ? qsTr("Read-only") : "", !field.enabled ? qsTr("Unavailable") : ""].filter(Boolean).join(". ")
        cursorDelegate: Rectangle {
            objectName: "ipFieldCursor"
            visible: input.cursorVisible && input.activeFocus && input.enabled && !input.readOnly
            width: 2
            color: Theme.accent
        }
        onCursorPositionChanged: field.rememberSelection()
        onSelectionStartChanged: field.rememberSelection()
        onSelectionEndChanged: field.rememberSelection()
        onTextEdited: {
            if (field.applying) return;
            field.acceptOperation(IpEdit.nativeEdit(field.positionState, field.configuration, text, field.pasting, field.backwardsDelete));
        }
        Keys.onPressed: function (event) { field.handleKey(event); }
        ThemeText {
            anchors.fill: parent
            leftPadding: input.leftPadding
            rightPadding: input.rightPadding
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0 && input.preeditText.length === 0
            text: field.readOnly || !field.enabled ? "—" : field.placeholder || (!field.inputValid ? "…" : "")
            color: field.inputValid ? Theme.subtleText : Theme.danger
            font.pixelSize: Theme.formValueSize
            Accessible.ignored: true
        }
    }
    DropArea {
        anchors.fill: parent
        enabled: field.editSession.available
        onEntered: function (drag) { drag.accepted = drag.hasText; }
        onDropped: function (drop) {
            drop.accepted = false;
            if (!drop.hasText) return;
            field.focusInput(false);
            input.cursorPosition = input.positionAt(drop.x, drop.y);
            const next = IpEdit.replace(field.positionState, field.configuration,
                Math.min(field.positionState.cursor, field.positionState.anchor),
                Math.max(field.positionState.cursor, field.positionState.anchor), drop.text, true, false);
            if (!next) return;
            field.acceptOperation(next);
            drop.accept(Qt.CopyAction);
        }
    }
    FieldStateBadge {
        id: stateBadge
        visible: field.readOnly || !field.enabled
        readOnly: field.readOnly
        unavailable: !field.enabled
        anchors.right: parent.right
        anchors.rightMargin: Theme.formPadding
        anchors.verticalCenter: parent.verticalCenter
    }
}
