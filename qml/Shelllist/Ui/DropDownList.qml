pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Controls.ComboBox {
    id: control

    property var options: []
    property string value: ""
    property bool interactive: true
    property string placeholder: "Select an option"

    signal selected(string value)

    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: optionIndex(value)
    implicitHeight: Theme.compactControlHeight
    leftPadding: Theme.spacingMd
    rightPadding: Theme.spacingLg + Theme.iconSizeSmall
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
    function optionText(option) { return option.label || option.value || ""; }
    function delegateTextColor(highlighted) { return highlighted ? Theme.accentText : Theme.text; }
    function delegateWeight(selected) {
        return selected ? Theme.fontWeightDemiBold : Theme.fontWeightRegular;
    }
    function delegateBackground(highlighted, selected, hovered) {
        if (highlighted)
            return Theme.accent;
        if (selected)
            return Theme.selected;
        return hovered ? Theme.hover : "transparent";
    }

    onActivated: function (index) {
        if (!optionEnabled(index))
            return;
        const nextValue = String(options[index].value || "");
        if (nextValue !== value)
            selected(nextValue);
    }

    contentItem: Text {
        leftPadding: 0
        rightPadding: 0
        text: control.optionLabel(control.currentIndex)
        color: control.currentIndex >= 0 ? Theme.inputText : Theme.subtleText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeBody
        font.weight: Theme.fontWeightMedium
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.width - width - Theme.spacingMd
        y: Math.round((control.height - height) / 2)
        text: "󰅀"
        color: control.popup.visible || control.activeFocus ? Theme.accent : Theme.mutedText
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeSmall
        rotation: control.popup.visible ? 180 : 0

        Behavior on rotation {
            enabled: !Theme.noAnimations
            NumberAnimation {
                duration: Theme.animationFast
                easing.type: Theme.easingStandard
            }
        }
    }

    background: Rectangle {
        radius: Theme.controlRadius
        color: control.pressed ? Theme.pressed
            : (control.hovered ? Theme.hover : Theme.input)
        border.width: 1
        border.color: control.activeFocus || control.popup.visible ? Theme.strongBorder : Theme.border
    }

    delegate: DropDownOptionDelegate { owner: control }

    popup: Controls.Popup {
        y: control.height + Theme.spacingXs
        width: control.width
        padding: Theme.spacingXs
        height: Math.min(
            control.options.length * Theme.compactControlHeight + topPadding + bottomPadding,
            Theme.compactControlHeight * 6 + topPadding + bottomPadding
        )

        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            boundsBehavior: Flickable.StopAtBounds
        }

        background: Rectangle {
            radius: Theme.controlRadius
            color: Theme.surfaceRaised
            border.width: 1
            border.color: Theme.strongBorder
        }

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Theme.noAnimations ? 0 : Theme.animationFast
                easing.type: Theme.easingStandard
            }
        }
        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Theme.noAnimations ? 0 : Theme.animationFast
                easing.type: Theme.easingStandard
            }
        }
    }
}
