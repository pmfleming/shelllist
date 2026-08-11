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
    property bool readOnly: false
    property bool inputValid: true
    property int inputMethodHints: Qt.ImhNone
    property int maximumLength: 32767
    property int fontPixelSize: Theme.fontSizeBody
    property string trailingActionIcon: ""
    property string trailingActionToolTip: ""
    property bool trailingActionEnabled: true
    property int trailingActionIconSize: Theme.iconSize
    readonly property int effectiveRightPadding: trailingActionIcon.length > 0
        ? Math.max(rightPadding, height) : rightPadding

    signal edited(string value)
    signal editingFinished
    signal accepted
    signal keyPressed(var event)
    signal trailingActionRequested

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
        echoMode: field.password ? TextInput.Password : TextInput.Normal
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
        visible: field.trailingActionIcon.length > 0
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXs
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, field.height - 2 * Theme.spacingXs)
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
