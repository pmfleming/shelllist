pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayFocusModel.js" as Focus

ColumnLayout {
    id: setting
    required property DisplayController controller
    required property var entry
    readonly property var values: controller.focusState.values || ({})
    readonly property bool supported: values[entry.key] !== undefined
    readonly property var observed: values[entry.key]
    readonly property bool editable: supported && controller.canSetFocus
    property var numberDraft: null
    readonly property string numberText: numberDraft !== null ? numberDraft : String(observed === undefined ? "" : observed)
    spacing: Ui.Theme.spacingXs
    onObservedChanged: numberDraft = null

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: setting.entry.title
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: setting.entry.help
        wrapMode: Text.Wrap
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.DropDownList {
        id: choice
        objectName: "focusSetting-" + setting.entry.key
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        visible: setting.entry.choices.length > 0
        options: setting.entry.choices
        value: setting.supported ? String(setting.observed) : ""
        interactive: setting.editable
        Accessible.name: setting.entry.title
        Accessible.description: setting.entry.help
        onSelected: function (value) {
            setting.controller.setFocusSetting(setting.entry.key, Focus.value(setting.entry, value));
            currentIndex = Qt.binding(function () {
                return choice.optionIndex(choice.value);
            });
        }
    }
    Ui.TextField {
        objectName: "focusNumber-" + setting.entry.key
        Layout.fillWidth: true
        visible: setting.entry.choices.length === 0
        enabled: setting.editable
        text: setting.numberText
        inputValid: !setting.supported || Focus.validNumber(setting.entry, text)
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        maximumLength: 10
        Accessible.name: setting.entry.title
        Accessible.description: qsTr("Enter a value, then press Enter or Apply to save")
        trailingActionIcon: "󰄬"
        trailingActionToolTip: qsTr("Apply")
        trailingActionEnabled: inputValid && Number(text) !== setting.observed
        onEdited: function (value) {
            setting.numberDraft = value;
        }
        onAccepted: save()
        onTrailingActionRequested: save()
        function save(): void {
            if (setting.editable && inputValid && Number(text) !== setting.observed)
                setting.controller.setFocusSetting(setting.entry.key, Number(text));
        }
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: !setting.supported ? qsTr("Unavailable in this compositor version") : setting.entry.key + (setting.entry.choices.length === 0 ? qsTr(" · Current: ") + setting.observed : "") + ((setting.controller.focusState.saved || {})[setting.entry.key] !== undefined ? qsTr(" · Saved override") : "")
        wrapMode: Text.Wrap
        font.pixelSize: Ui.Theme.fontSizeCaption
        color: setting.supported ? Ui.Theme.subtleText : Ui.Theme.warning
    }
}
