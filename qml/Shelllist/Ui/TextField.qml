import QtQuick

FieldFrame {
    id: field

    readonly property FieldEditSession editSession: FieldEditSession {
        owner: field
        available: field.enabled && !field.readOnly
        valueProperty: "text"
        focused: field.inputActiveFocus
        value: field.text
        onRestoreRequested: function (value) { field.text = value; }
        onPublishRequested: function (value) { field.edited(value); }
        onFinished: function (saved) { if (saved) field.editingFinished(); }
    }
    property string focusKey: objectName
    property alias text: input.text
    property alias horizontalAlignment: input.horizontalAlignment
    property alias cursorPosition: input.cursorPosition
    property bool compact: false
    property string supportingText: ""
    property string errorText: ""
    property string prefix: ""
    property string suffix: ""
    property int leftPadding: Theme.formPadding
    property int rightPadding: Theme.formPadding
    readonly property alias inputActiveFocus: input.activeFocus
    property string placeholder: ""
    property bool password: false
    // Classification is independent of whether an explicit reveal is visible.
    property bool sensitive: password
    property bool passwordRevealed: false
    property bool showPasswordButton: password
    property bool inputValid: true
    property int inputMethodHints: Qt.ImhNone
    property int maximumLength: 32767
    property int fontPixelSize: Theme.formValueSize
    property string fontFamily: Theme.fontFamily
    readonly property alias trailingAction: trailingActionButton
    property string trailingActionIcon: ""
    property string trailingActionToolTip: ""
    property bool trailingActionEnabled: true
    property int trailingActionIconSize: Theme.formActionIconSize
    readonly property int embeddedActionWidth: Theme.formActionSize
    readonly property int embeddedActionCount: (showPasswordButton ? 1 : 0) + (trailingActionIcon.length > 0 ? 1 : 0)
    readonly property int actionRightPadding: embeddedActionCount > 0 ? Math.max(rightPadding, Theme.spacingXs + embeddedActionCount * embeddedActionWidth + (embeddedActionCount - 1) * Theme.spacingXs) : rightPadding
    readonly property int effectiveRightPadding: actionRightPadding + (stateBadge.visible ? stateBadge.width + Theme.spacingSm : 0)

    signal selectionChanged
    signal edited(string value)
    signal editingFinished
    signal accepted
    signal keyPressed(var event)
    signal trailingActionRequested

    onPasswordChanged: if (!password)
        passwordRevealed = false
    onVisibleChanged: if (!visible)
        passwordRevealed = false

    implicitHeight: compact ? Theme.formCompactHeight : Theme.formHeight
    focused: input.activeFocus && !readOnly
    invalid: !inputValid || errorText.length > 0
    hovered: hover.hovered
    // Unavailable is a state, not permission to make the value illegible.
    opacity: 1

    function focusInput(selectContents) {
        input.forceActiveFocus();
        if (selectContents)
            input.selectAll();
    }

    // Positions only: never retain text, preedit/IME state or password metadata.
    function selectionState(): var {
        if (sensitive)
            return null;
        return {cursor: input.cursorPosition, anchor: input.cursorPosition === input.selectionStart ? input.selectionEnd : input.selectionStart};
    }
    function restoreSelection(state: var): void {
        if (sensitive || !state || !Number.isFinite(state.cursor) || !Number.isFinite(state.anchor))
            return;
        const cursor = Math.max(0, Math.min(input.text.length, state.cursor));
        const anchor = Math.max(0, Math.min(input.text.length, state.anchor));
        input.select(anchor, cursor);
    }

    // Continue an ordinary query after a printable key in the result region.
    // Native insert retains cursor/selection semantics and maximumLength.
    function insertText(value: string): void {
        if (!enabled || readOnly)
            return;
        focusInput(false);
        const position = input.selectionStart;
        input.remove(input.selectionStart, input.selectionEnd);
        input.insert(position, value);
        if (!editSession.active)
            field.edited(input.text);
    }

    HoverHandler {
        id: hover
        enabled: field.enabled
    }

    TextInput {
        id: input
        objectName: "fieldInput"
        Accessible.name: field.Accessible.name || field.placeholder
        Accessible.description: [field.Accessible.description, field.suffix, !field.enabled ? qsTr("Unavailable") : field.readOnly ? qsTr("Read-only") : "", field.readOnly && !field.text.length ? qsTr("Not set") : ""].filter(part => part.length > 0).join(". ")

        anchors.fill: parent
        clip: true
        leftPadding: field.leftPadding + (prefixLabel.visible ? prefixLabel.implicitWidth + Theme.spacingSm : 0)
        rightPadding: field.effectiveRightPadding + (suffixLabel.visible ? suffixLabel.implicitWidth + Theme.spacingSm : 0) + (errorIcon.visible ? Theme.formIconSize + Theme.spacingSm : 0)
        selectByMouse: true
        readOnly: field.readOnly
        inputMethodHints: field.inputMethodHints
        maximumLength: field.maximumLength
        echoMode: field.password && !field.passwordRevealed ? TextInput.Password : TextInput.Normal
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        cursorDelegate: Rectangle {
            width: 2
            color: Theme.accent
        }
        font.family: field.fontFamily
        font.pixelSize: field.fontPixelSize
        verticalAlignment: TextInput.AlignVCenter
        onCursorPositionChanged: field.selectionChanged()
        onSelectionStartChanged: field.selectionChanged()
        onSelectionEndChanged: field.selectionChanged()
        onTextEdited: if (!field.editSession.active) field.edited(text)
        onEditingFinished: if (!field.editSession.navigation) field.editingFinished()
        onAccepted: if (!field.editSession.navigation) field.accepted()
        Keys.onPressed: function (event) {
            field.keyPressed(event);
        }

        ThemeText {
            objectName: "fieldPlaceholder"
            anchors.fill: parent
            leftPadding: input.leftPadding
            rightPadding: input.rightPadding
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0 && input.preeditText.length === 0
            // Never present an example IP/password as an observed value.
            text: field.readOnly || !field.enabled ? "—" : field.placeholder
            color: Theme.subtleText
            font.pixelSize: field.fontPixelSize
        }
    }

    ThemeText {
        id: prefixLabel
        visible: field.prefix.length > 0
        anchors.left: parent.left
        anchors.leftMargin: field.leftPadding
        anchors.verticalCenter: parent.verticalCenter
        text: field.prefix
        font.pixelSize: Theme.formValueSize
        color: Theme.mutedText
        Accessible.ignored: true
    }
    ThemeText {
        id: suffixLabel
        visible: field.suffix.length > 0
        anchors.right: parent.right
        anchors.rightMargin: field.effectiveRightPadding + (errorIcon.visible ? Theme.formIconSize + Theme.spacingSm : 0)
        anchors.verticalCenter: parent.verticalCenter
        text: field.suffix
        font.pixelSize: Theme.formLabelSize
        color: Theme.mutedText
        Accessible.ignored: true
    }
    GlyphLabel {
        id: errorIcon
        objectName: "fieldErrorIcon"
        visible: field.invalid && field.formStyle
        anchors.right: parent.right
        anchors.rightMargin: field.effectiveRightPadding
        anchors.verticalCenter: parent.verticalCenter
        glyph: "error"
        font.pixelSize: Theme.formIconSize
        color: Theme.danger
        Accessible.ignored: true
    }

    FieldStateBadge {
        id: stateBadge
        objectName: "fieldStateBadge"
        visible: field.formStyle && (readOnly || unavailable)
        readOnly: field.readOnly
        unavailable: !field.enabled
        anchors.right: parent.right
        anchors.rightMargin: field.actionRightPadding
        anchors.verticalCenter: parent.verticalCenter
    }

    FlatIconButton {
        objectName: "passwordVisibilityAction"
        commandScope: field.readOnly ? null : field
        accessKey: field.readOnly ? "" : "V"
        visible: field.showPasswordButton
        anchors.right: trailingActionButton.visible ? trailingActionButton.left : parent.right
        anchors.rightMargin: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: field.embeddedActionWidth
        height: width
        icon: field.passwordRevealed ? "󰈉" : "󰈈"
        flatIconColor: Theme.text
        iconSize: Theme.formActionIconSize
        accessibleName: (field.passwordRevealed ? qsTr("Hide password: %1") : qsTr("Show password: %1")).arg(field.Accessible.name || field.placeholder)
        onClicked: field.passwordRevealed = !field.passwordRevealed
    }

    FlatIconButton {
        id: trailingActionButton
        objectName: "fieldTrailingAction"
        commandScope: field.readOnly ? null : field

        visible: field.trailingActionIcon.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: field.embeddedActionWidth
        height: width
        icon: field.trailingActionIcon
        flatIconColor: Theme.text
        iconSize: field.trailingActionIconSize
        enabled: field.trailingActionEnabled
        accessibleName: field.trailingActionToolTip
        onClicked: field.trailingActionRequested()
    }
}
