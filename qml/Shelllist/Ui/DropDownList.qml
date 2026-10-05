pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Controls.ComboBox {
    id: control

    property bool compact: false
    property string supportingText: ""
    property string errorText: ""
    property var options: []
    property string value: ""
    property bool interactive: true
    property bool browseFocused: false
    property string placeholder: "Select an option"
    property string draftValue: value
    readonly property int selectedIndex: optionIndex(editSession.active ? draftValue : value)
    readonly property FieldEditSession editSession: FieldEditSession {
        owner: control
        available: control.enabled && control.interactive
        value: control.draftValue
        initialValue: control.value
        onActiveChanged: if (active) control.draftValue = control.value
        onRestoreRequested: function (value) { control.draftValue = value; }
        onPublishRequested: function (value) { control.selected(value); }
    }
    function stageIndex(index: int): void {
        if (!enabled || !interactive || !optionEnabled(index))
            return;
        const nextValue = String(options[index].value || "");
        if (editSession.active)
            draftValue = nextValue;
        else if (nextValue !== value)
            selected(nextValue);
    }

    Keys.onPressed: function (event) { editSession.handleKey(event); }

    signal selected(string value)

    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: selectedIndex
    implicitHeight: compact ? Theme.formCompactHeight : Theme.formHeight
    leftPadding: mirrored ? Theme.formActionSize : Theme.formPadding
    rightPadding: mirrored ? Theme.formPadding : Theme.formActionSize
    hoverEnabled: true
    enabled: interactive
    activeFocusOnTab: enabled
    opacity: enabled ? 1.0 : Theme.disabledOpacity

    function optionIndex(optionValue) {
        for (let index = 0; index < options.length; ++index)
            if (String(options[index].value || "") === String(optionValue || ""))
                return index;
        return -1;
    }

    function optionEnabled(index) {
        return index >= 0 && index < options.length && options[index].enabled !== false;
    }

    function optionLabel(index) {
        if (index < 0 || index >= options.length)
            return placeholder;
        return optionText(options[index]) || placeholder;
    }
    function optionText(option) {
        return option.label || option.value || "";
    }
    onActivated: function (index) { stageIndex(index); }

    contentItem: ThemeText {
        leftPadding: 0
        rightPadding: 0
        // Native currentIndex may be a proposed choice awaiting acknowledgement.
        text: control.optionLabel(control.selectedIndex)
        color: control.selectedIndex >= 0 ? Theme.inputText : Theme.subtleText
        font.pixelSize: Theme.formValueSize
        font.weight: Theme.fontWeightRegular
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.mirrored ? Theme.spacingMd : control.width - width - Theme.spacingMd
        y: Math.round((control.height - height) / 2)
        text: "󰅀"
        color: control.popup.visible || control.activeFocus || control.browseFocused ? Theme.accent : Theme.mutedText
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.formIconSize
        rotation: indicatorMotion.value

        ExpressiveMotion {
            id: indicatorMotion
            target: control.popup.visible ? 180 : 0
        }
    }

    background: FieldFrame {
        focused: control.activeFocus || control.popup.visible
        browseFocused: control.browseFocused
        hovered: control.hovered
        invalid: control.errorText.length > 0
    }

    delegate: DropDownOptionDelegate {
        owner: control
    }

    popup: Controls.Popup {
        closePolicy: Controls.Popup.CloseOnPressOutside
        y: control.height + Theme.spacingXs
        width: control.width
        padding: Theme.spacingSm
        height: Math.min(control.options.length, 6) * Theme.formCompactHeight + topPadding + bottomPadding

        contentItem: ScrollableListView {
            Keys.onPressed: function (event) { control.editSession.handleKey(event); }
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }

        background: Rectangle {
            radius: 12
            color: Theme.surfaceRaised
            border.width: 1
            border.color: Theme.border
        }

        // The newly focused option must never wait behind a fade.
        enter: null
        exit: null
    }
}
