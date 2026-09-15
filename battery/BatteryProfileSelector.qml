pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Item {
    id: selector

    property var options: []
    property string value: ""
    property bool interactive: true
    property string accessibleName: qsTr("Power profile")
    readonly property int buttonSize: 36
    signal selected(string value)

    implicitWidth: buttons.implicitWidth
    implicitHeight: buttonSize
    Accessible.role: Accessible.Grouping
    Accessible.name: accessibleName

    function optionEnabled(index: int): bool {
        return index >= 0 && index < options.length && options[index].enabled !== false;
    }

    function choose(index: int): void {
        if (interactive && enabled && optionEnabled(index) && options[index].value !== value)
            selected(options[index].value);
    }

    function move(delta: int): void {
        if (!interactive || !enabled || (delta !== -1 && delta !== 1))
            return;
        let index = options.findIndex(function (option) { return option.value === selector.value; });
        if (index < 0)
            index = delta > 0 ? -1 : options.length;
        for (index += delta; index >= 0 && index < options.length; index += delta) {
            if (optionEnabled(index)) {
                choose(index);
                const button = repeater.itemAt(index);
                if (button)
                    button.forceActiveFocus();
                return;
            }
        }
    }

    Keys.onLeftPressed: function (event) {
        selector.move(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: function (event) {
        selector.move(1);
        event.accepted = true;
    }

    RowLayout {
        id: buttons
        anchors.fill: parent
        spacing: Ui.Theme.spacingXs

        Repeater {
            id: repeater
            model: selector.options

            delegate: Ui.ActionButton {
                required property int index
                required property var modelData
                readonly property bool selected: selector.value === modelData.value
                readonly property color profileColor: modelData.value === "power-saver" ? Ui.Theme.active : (modelData.value === "balanced" ? Ui.Theme.accent : (modelData.value === "performance" ? Ui.Theme.warning : Ui.Theme.mutedText))

                objectName: "profileOption-" + modelData.value
                Layout.preferredWidth: selector.buttonSize
                Layout.preferredHeight: selector.buttonSize
                icon: modelData.value === "power-saver" ? "" : (modelData.value === "balanced" ? "" : "")
                iconSize: Ui.Theme.iconSizeLarge
                accessibleName: selector.accessibleName + ": " + modelData.label
                toolTip: modelData.label + (selected ? qsTr(" (selected)") : "")
                labelColor: profileColor
                backgroundColor: selected ? Ui.Theme.withAlpha(profileColor, 0.18) : Ui.Theme.input
                borderColor: selected ? profileColor : "transparent"
                enabled: selector.interactive && selector.optionEnabled(index)
                Accessible.role: Accessible.RadioButton
                Accessible.checkable: true
                Accessible.checked: selected
                onClicked: selector.choose(index)
            }
        }
    }
}
