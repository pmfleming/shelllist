pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as Controls

Controls.ComboBox {
    id: control

    property var options: []
    property string value: ""
    property bool interactive: true
    property bool browseFocused: false
    property string placeholder: "Select an option"
    readonly property int selectedIndex: optionIndex(value)

    signal selected(string value)

    model: options
    textRole: "label"
    valueRole: "value"
    currentIndex: selectedIndex
    implicitHeight: Theme.controlHeight
    leftPadding: mirrored ? Theme.spacingLg + Theme.iconSizeSmall : Theme.spacingMd
    rightPadding: mirrored ? Theme.spacingMd : Theme.spacingLg + Theme.iconSizeSmall
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
    onActivated: function (index) {
        if (!enabled || !interactive || !optionEnabled(index))
            return;
        const nextValue = String(options[index].value || "");
        if (nextValue !== value)
            selected(nextValue);
    }

    contentItem: ThemeText {
        leftPadding: 0
        rightPadding: 0
        // Native currentIndex may be a proposed choice awaiting acknowledgement.
        text: control.optionLabel(control.selectedIndex)
        color: control.selectedIndex >= 0 ? Theme.inputText : Theme.subtleText
        font.weight: Theme.fontWeightMedium
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Text {
        x: control.mirrored ? Theme.spacingMd : control.width - width - Theme.spacingMd
        y: Math.round((control.height - height) / 2)
        text: "󰅀"
        color: control.popup.visible || control.activeFocus || control.browseFocused ? Theme.accent : Theme.mutedText
        font.family: Theme.iconFontFamily
        font.pixelSize: Theme.iconSizeSmall
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
    }

    delegate: DropDownOptionDelegate {
        owner: control
    }

    popup: Controls.Popup {
        y: control.height + Theme.spacingXs
        width: control.width
        padding: Theme.spacingSm
        height: Math.min(control.options.length, 6) * Theme.controlHeight + topPadding + bottomPadding

        contentItem: ScrollableListView {
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
