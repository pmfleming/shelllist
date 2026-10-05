pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "DisplayFocusModel.js" as Focus

ColumnLayout {
    id: setting
    required property DisplayController controller
    required property var entry
    property bool helpOpen: false
    readonly property var values: controller.focusState.values || ({})
    readonly property bool supported: values[entry.key] !== undefined
    readonly property var observed: values[entry.key]
    readonly property bool editable: supported && controller.canSetFocus
    property var numberDraft: null
    property bool validationAttempted: false
    readonly property string numberText: numberDraft !== null ? numberDraft : String(observed === undefined ? "" : observed)
    spacing: Ui.Theme.spacingXs
    onObservedChanged: {
        numberDraft = null;
        validationAttempted = false;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Ui.ToggleRow {
            objectName: setting.entry.boolean ? "focusSetting-" + setting.entry.key : ""
            Layout.fillWidth: true
            visible: !!setting.entry.boolean
            title: setting.entry.title
            wrapTitle: true
            checked: setting.observed === true
            interactive: setting.editable
            Accessible.description: setting.entry.help
            onClicked: setting.controller.setFocusSetting(setting.entry.key, !checked)
        }
        Ui.FormField {
            Layout.fillWidth: true
            visible: !setting.entry.boolean
            label: setting.entry.title
            editor: setting.entry.choices.length > 0 ? choice : numberField
            Ui.DropDownList {
                id: choice
                objectName: !setting.entry.boolean ? "focusSetting-" + setting.entry.key : ""
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 230
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
                id: numberField
                objectName: "focusNumber-" + setting.entry.key
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 160
                visible: setting.entry.choices.length === 0
                enabled: setting.editable
                text: setting.numberText
                inputValid: !setting.supported || Focus.validNumber(setting.entry, text)
                invalid: setting.validationAttempted && !inputValid
                suffix: setting.entry.unit || ""
                supportingText: qsTr("0–%1 %2").arg(setting.entry.maximum).arg(suffix).trim()
                inputMethodHints: Qt.ImhFormattedNumbersOnly
                maximumLength: 10
                Accessible.name: setting.entry.title
                errorText: !setting.validationAttempted || inputValid ? "" : qsTr("Enter a valid value for %1").arg(setting.entry.title)
                trailingActionIcon: "󰄬"
                trailingActionToolTip: qsTr("Apply")
                trailingActionEnabled: inputValid && Number(text) !== setting.observed
                onEdited: function (value) {
                    setting.numberDraft = value;
                }
                onEditingFinished: save()
                onTrailingActionRequested: save()
                function save(): void {
                    setting.validationAttempted = true;
                    if (setting.editable && inputValid && Number(text) !== setting.observed)
                        setting.controller.setFocusSetting(setting.entry.key, Number(text));
                }
            }
        }
        Ui.FlatIconButton {
            objectName: "focusHelp-" + setting.entry.key
            accessKey: "H"
            commandScope: setting
            Layout.preferredWidth: Ui.Theme.formActionSize
            Layout.preferredHeight: Ui.Theme.formActionSize
            icon: setting.helpOpen ? "expand_less" : "help_outline"
            accessibleName: qsTr("Help: %1").arg(setting.entry.title)
            Accessible.description: setting.entry.help
            onClicked: setting.helpOpen = !setting.helpOpen
        }
    }
    Ui.ThemeText {
        objectName: "focusHelpText-" + setting.entry.key
        Layout.fillWidth: true
        visible: setting.helpOpen
        text: setting.entry.help
        wrapMode: Text.Wrap
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        visible: !setting.supported
        text: qsTr("Unavailable in this compositor version")
        wrapMode: Text.Wrap
        color: Ui.Theme.warning
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
