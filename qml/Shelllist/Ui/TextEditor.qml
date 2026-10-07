import QtQuick
import QtQuick.Controls as Controls

// A bounded native multiline editor. The focus scope preserves the shared
// navigation identity while its TextEdit owns IME, selection and the caret.
FocusScope {
    id: editor
    property string focusKey: objectName
    property bool browseFocused: false
    property bool rowEmbedded: false
    property int maximumImplicitHeight: Theme.formTextAreaHeight
    property bool editingAllowed: !readOnly
    property string supportingText: ""
    property string errorText: ""
    property alias text: input.text
    property alias readOnly: input.readOnly
    property alias color: input.color
    property alias selectionColor: input.selectionColor
    property alias selectedTextColor: input.selectedTextColor
    property alias font: input.font
    property alias wrapMode: input.wrapMode
    property alias selectByMouse: input.selectByMouse
    property alias cursorPosition: input.cursorPosition
    property alias inputMethodHints: input.inputMethodHints
    readonly property alias contentHeight: viewport.contentHeight
    readonly property alias contentY: viewport.contentY
    signal edited(string value)
    signal editFinished(bool saved)
    signal selectionChanged
    implicitHeight: Math.max(Theme.formHeight, Math.min(maximumImplicitHeight, input.implicitHeight))
    implicitWidth: 240
    opacity: 1

    readonly property FieldEditSession editSession: FieldEditSession {
        owner: editor
        // Some domains explicitly allow entry to acquire a lease before the
        // native TextEdit becomes writable (Clipboard). Keep that gate intact.
        available: editor.enabled && editor.editingAllowed
        multiline: true
        valueProperty: "text"
        value: editor.text
        onRestoreRequested: function (value) { editor.text = value; }
        onPublishRequested: function (value) { editor.edited(value); }
        onFinished: function (saved) { editor.editFinished(saved); }
    }
    FontMetrics {
        id: inputMetrics
        font: input.font
    }
    FieldFrame {
        anchors.fill: parent
        focused: editor.editSession.active || (editor.activeFocus && !editor.readOnly)
        browseFocused: editor.browseFocused
        invalid: editor.errorText.length > 0
        rowEmbedded: editor.rowEmbedded
        readOnly: !editor.editingAllowed
    }
    Flickable {
        id: viewport
        objectName: "textEditorViewport"
        anchors.fill: parent
        anchors.rightMargin: stateBadge.visible ? stateBadge.width + Theme.spacingSm : (errorIcon.visible ? Theme.formIconSize + Theme.spacingSm : 0)
        clip: true
        contentWidth: width
        contentHeight: input.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        Controls.ScrollBar.vertical: Controls.ScrollBar { }
        TextEdit {
            id: input
            objectName: "multilineInput"
            width: viewport.width
            height: Math.max(viewport.height, implicitHeight)
            focus: true
            padding: Theme.formPadding
            topPadding: Math.max(Theme.formPadding, Math.floor((Theme.formHeight - inputMetrics.height) / 2))
            bottomPadding: topPadding
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            selectByMouse: true
            color: Theme.inputText
            selectionColor: Theme.accent
            selectedTextColor: Theme.accentText
            font.family: Theme.fontFamily
            font.pixelSize: Theme.formValueSize
            Accessible.name: editor.Accessible.name
            Accessible.description: [editor.Accessible.description, !editor.enabled ? qsTr("Unavailable") : editor.readOnly || !editor.editingAllowed ? qsTr("Read-only") : "", editor.readOnly && !editor.text.length ? qsTr("Not set") : ""].filter(part => part.length > 0).join(". ")
            Keys.onPressed: function (event) { editor.editSession.handleKey(event); }
            onCursorPositionChanged: editor.selectionChanged()
            onSelectionStartChanged: editor.selectionChanged()
            onSelectionEndChanged: editor.selectionChanged()
            onCursorRectangleChanged: editor.revealCursor()
            onTextEdited: if (!editor.editSession.navigation) editor.edited(text)
            ThemeText {
                objectName: "fieldPlaceholder"
                x: input.leftPadding
                y: input.topPadding
                visible: input.text.length === 0 && input.preeditText.length === 0 && (editor.readOnly || !editor.enabled)
                text: "—"
                color: Theme.subtleText
                font: input.font
                Accessible.ignored: true
            }
        }
    }
    FieldStateBadge {
        id: stateBadge
        objectName: "fieldStateBadge"
        readOnly: !editor.editingAllowed
        unavailable: !editor.enabled
        anchors.right: parent.right
        anchors.rightMargin: Theme.formPadding
        anchors.top: parent.top
        anchors.topMargin: (Theme.formHeight - height) / 2
    }
    GlyphLabel {
        id: errorIcon
        objectName: "fieldErrorIcon"
        visible: editor.errorText.length > 0 && !stateBadge.visible
        anchors.right: parent.right
        anchors.rightMargin: Theme.formPadding
        anchors.top: parent.top
        anchors.topMargin: (Theme.formHeight - height) / 2
        glyph: "error"
        font.pixelSize: Theme.formIconSize
        color: Theme.danger
        Accessible.ignored: true
    }
    function revealCursor(): void {
        if (!input.activeFocus)
            return;
        const caret = input.cursorRectangle;
        if (caret.y < viewport.contentY)
            viewport.contentY = caret.y;
        else if (caret.y + caret.height > viewport.contentY + viewport.height)
            viewport.contentY = caret.y + caret.height - viewport.height;
        viewport.returnToBounds();
    }
    function select(start: int, end: int): void { input.select(start, end); }
    function selectAll(): void { input.selectAll(); }
    function selectionState(): var {
        return {cursor: input.cursorPosition, anchor: input.cursorPosition === input.selectionStart ? input.selectionEnd : input.selectionStart};
    }
    function restoreSelection(state: var): void {
        if (!state || !Number.isFinite(state.cursor) || !Number.isFinite(state.anchor))
            return;
        input.select(Math.max(0, Math.min(text.length, state.anchor)), Math.max(0, Math.min(text.length, state.cursor)));
    }
}
