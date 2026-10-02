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
    readonly property string numberText: numberDraft !== null ? numberDraft : String(observed === undefined ? "" : observed)
    spacing: Ui.Theme.spacingXs
    onObservedChanged: numberDraft = null

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
        GridLayout {
            Layout.fillWidth: true
            visible: !setting.entry.boolean
            columns: width >= 380 ? 2 : 1
            columnSpacing: Ui.Theme.spacingMd
            rowSpacing: Ui.Theme.spacingXs
            Ui.FieldLabel {
                Layout.fillWidth: true
                Layout.preferredWidth: 160
                text: setting.entry.title
                wrapMode: Text.Wrap
                elide: Text.ElideNone
            }
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
                objectName: "focusNumber-" + setting.entry.key
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 160
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
                onEdited: function (value) { setting.numberDraft = value; }
                onAccepted: save()
                onTrailingActionRequested: save()
                function save(): void {
                    if (setting.editable && inputValid && Number(text) !== setting.observed)
                        setting.controller.setFocusSetting(setting.entry.key, Number(text));
                }
            }
        }
        Ui.FlatIconButton {
            objectName: "focusHelp-" + setting.entry.key
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
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
