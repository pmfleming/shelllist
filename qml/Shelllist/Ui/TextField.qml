import QtQuick
import QtQuick.Controls as Controls

Rectangle {
    id: field

    property alias text: input.text
    property alias horizontalAlignment: input.horizontalAlignment
    property alias cursorPosition: input.cursorPosition
    property int leftPadding: Theme.spacingMd
    property int rightPadding: Theme.spacingMd
    readonly property alias inputActiveFocus: input.activeFocus
    property string placeholder: ""
    property bool password: false
    property bool passwordRevealed: false
    property bool showPasswordButton: password
    property bool readOnly: false
    property bool inputValid: true
    property int inputMethodHints: Qt.ImhNone
    property int maximumLength: 32767
    property int fontPixelSize: Theme.fontSizeBody
    property string trailingActionIcon: ""
    property string trailingActionToolTip: ""
    property bool trailingActionEnabled: true
    property int trailingActionIconSize: Theme.iconSize
    readonly property int embeddedActionWidth: Math.max(0, height - 2 * Theme.spacingXs)
    readonly property int embeddedActionCount: (showPasswordButton ? 1 : 0)
        + (trailingActionIcon.length > 0 ? 1 : 0)
    readonly property int effectiveRightPadding: embeddedActionCount > 0
        ? Math.max(rightPadding, Theme.spacingXs
            + embeddedActionCount * embeddedActionWidth
            + (embeddedActionCount - 1) * Theme.spacingXs)
        : rightPadding

    signal edited(string value)
    signal editingFinished
    signal accepted
    signal keyPressed(var event)
    signal trailingActionRequested

    onPasswordChanged: if (!password) passwordRevealed = false
    onVisibleChanged: if (!visible) passwordRevealed = false

    implicitHeight: Theme.compactControlHeight
    radius: Theme.controlRadius
    color: Theme.input
    border.color: !inputValid ? Theme.danger : (input.activeFocus ? Theme.strongBorder : Theme.border)
    opacity: enabled ? (readOnly ? Theme.readOnlyOpacity : 1.0) : Theme.disabledOpacity

    function focusInput(selectContents) {
        input.forceActiveFocus();
        if (selectContents)
            input.selectAll();
    }

    TextInput {
        id: input

        anchors.fill: parent
        leftPadding: field.leftPadding
        rightPadding: field.effectiveRightPadding
        readOnly: field.readOnly
        inputMethodHints: field.inputMethodHints
        maximumLength: field.maximumLength
        echoMode: field.password && !field.passwordRevealed
            ? TextInput.Password : TextInput.Normal
        color: Theme.inputText
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: field.fontPixelSize
        verticalAlignment: TextInput.AlignVCenter
        onTextEdited: field.edited(text)
        onEditingFinished: field.editingFinished()
        onAccepted: field.accepted()
        Keys.onPressed: function (event) { field.keyPressed(event); }

        Text {
            anchors.fill: parent
            leftPadding: input.leftPadding
            rightPadding: input.rightPadding
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: Theme.subtleText
            font.family: Theme.fontFamily
            font.pixelSize: field.fontPixelSize
        }
    }

    IconTile {
        id: passwordButton

        visible: field.showPasswordButton
        anchors.right: trailingAction.visible ? trailingAction.left : parent.right
        anchors.rightMargin: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: field.embeddedActionWidth
        height: width
        icon: field.passwordRevealed ? "󰈉" : "󰈈"
        iconColor: Theme.text
        iconSize: Theme.iconSize
        clickable: true
        onClicked: field.passwordRevealed = !field.passwordRevealed

        Accessible.role: Accessible.Button
        Accessible.name: field.passwordRevealed ? "Hide password" : "Show password"
        Accessible.onPressAction: field.passwordRevealed = !field.passwordRevealed

        HoverHandler { id: passwordButtonHover }
        Controls.ToolTip.visible: passwordButtonHover.hovered
        Controls.ToolTip.text: field.passwordRevealed ? "Hide password" : "Show password"
        Controls.ToolTip.delay: 450
    }

    IconTile {
        id: trailingAction

        visible: field.trailingActionIcon.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: field.embeddedActionWidth
        height: width
        icon: field.trailingActionIcon
        iconColor: field.trailingActionEnabled ? Theme.text : Theme.disabledText
        iconSize: field.trailingActionIconSize
        clickable: field.trailingActionEnabled
        enabled: field.trailingActionEnabled
        onClicked: field.trailingActionRequested()

        Accessible.role: Accessible.Button
        Accessible.name: field.trailingActionToolTip
        Accessible.onPressAction: if (field.trailingActionEnabled) field.trailingActionRequested()

        HoverHandler { id: trailingActionHover }
        Controls.ToolTip.visible: trailingActionHover.hovered && field.trailingActionToolTip.length > 0
        Controls.ToolTip.text: field.trailingActionToolTip
        Controls.ToolTip.delay: 450
    }
}
