pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Controls.ComboBox {
    id: control

    property bool compact: false
    property bool rowEmbedded: false
    property string supportingText: ""
    property string errorText: ""
    property var options: []
    property string value: ""
    property bool interactive: true
    // Explicit option clicks may save; keyboard browsing remains a local draft.
    property bool saveOnOptionClick: false
    property bool browseFocused: false
    property string placeholder: "Select an option"
    readonly property int acknowledgedIndex: optionIndex(value)
    readonly property int selectedIndex: optionIndex(editSession.displayedValue)
    readonly property string selectedIcon: selectedIndex >= 0 ? String(options[selectedIndex].icon || "") : ""
    readonly property ChoiceEditSession editSession: ChoiceEditSession {
        owner: control
        available: control.enabled && control.interactive
        sourceValue: control.value
        onPublishRequested: function (value) { control.selected(value); }
    }
    function stageIndex(index: int): void {
        if (!enabled || !interactive || !optionEnabled(index))
            return;
        editSession.choose(String(options[index].value || ""));
    }

    function acceptOptionClick(index: int): void {
        // Outside a navigation transaction, native activation already publishes.
        if (!saveOnOptionClick || !editSession.active || !editSession.navigation
                || !enabled || !interactive || !optionEnabled(index))
            return;
        stageIndex(index);
        // Do not let saveEditor replace the clicked choice with a keyboard highlight.
        popup.close();
        editSession.navigation.saveEditor();
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
    opacity: 1

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

    contentItem: DropDownLabel {
        // Native currentIndex may be a proposed choice awaiting acknowledgement.
        text: control.optionLabel(control.selectedIndex)
        color: control.selectedIndex >= 0 ? Theme.inputText : Theme.subtleText
        font.weight: Theme.fontWeightRegular
        leadingIcon.objectName: "dropDownValueIcon"
        leadingIcon.glyph: control.selectedIcon
        trailingIcon.objectName: "dropDownErrorIcon"
        trailingVisible: control.errorText.length > 0
        trailingIcon.glyph: "error"
        trailingIcon.color: Theme.danger
    }

    indicator: GlyphLabel {
        x: control.mirrored ? Theme.spacingMd : control.width - width - Theme.spacingMd
        y: Math.round((control.height - height) / 2)
        glyph: control.enabled && control.interactive ? "expand_more" : "block"
        color: control.popup.visible || control.activeFocus || control.browseFocused ? Theme.accent : Theme.mutedText
        font.pixelSize: Theme.formIconSize
        Accessible.ignored: true
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
        rowEmbedded: control.rowEmbedded
    }

    delegate: DropDownOptionDelegate {
        owner: control
    }

    popup: ChoicePopup {
        owner: control
        optionCount: control.options.length
        model: visible ? control.delegateModel : null
        currentIndex: control.highlightedIndex
        onKeyPressed: function(event) { control.editSession.handleKey(event); }
    }
}
