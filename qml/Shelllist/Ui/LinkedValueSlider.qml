pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// One normal slider field; exact values/Never are an explicit modal command.
// The caller owns units, constraints, acknowledgement and domain validation.
LabeledValueSlider {
    id: row
    property bool allowNever: false
    property bool interactive: true
    property string unit: "%"
    property string validationError: ""
    signal valueSelected(real selectedValue)
    enabled: interactive
    stepSize: 1
    valueText: formatValue(value)
    scaleStartText: scaleValues.length ? formatValue(scaleValues[0]) : ""
    scaleEndText: scaleValues.length ? formatValue(scaleValues[scaleValues.length - 1]) : ""
    scaleDescription: qsTr("Non-linear scale. Arrows select the next available step. Alt+V enters an exact value.")
    onEdited: {
        validationError = "";
        valueSelected(value);
    }
    onEditRejected: validationError = qsTr("The limits changed. Review the current values and try again.")
    onVisibleChanged: if (!visible) exactDialog.visible = false
    onEnabledChanged: if (!enabled) exactDialog.visible = false

    function formatValue(candidate: real): string {
        if (!Number.isFinite(candidate)) return "—";
        if (allowNever && candidate === 0) return qsTr("Never");
        if (unit === "%") return qsTr("%1%").arg(candidate);
        return candidate >= 60 && candidate % 60 === 0 ? qsTr("%1 h").arg(candidate / 60) : qsTr("%1 min").arg(candidate);
    }
    function valid(candidate: real): bool {
        return Number.isInteger(candidate) && ((allowNever && candidate === 0) || (candidate >= minimumValue && candidate <= maximumValue));
    }
    function openExact(): void {
        if (!enabled) return;
        // Opening a command is not an implicit save of a slider draft.
        if (editSession.navigation) {
            editSession.navigation.finishEditor(false);
            editSession.navigation.focusContent();
        }
        exactDialog.originalValue = value;
        exactDialog.originalPeer = peerValue;
        exactDialog.inputText = String(value);
        exactDialog.optionChecked = allowNever && value === 0;
        if (editSession.navigation) editSession.navigation.fieldModal = exactDialog;
        exactDialog.visible = true;
    }

    accessories: FlatIconButton {
        objectName: "linkedSliderExactCommand"
        Layout.preferredWidth: Theme.formActionSize
        Layout.preferredHeight: Theme.formActionSize
        iconSize: Theme.formActionIconSize
        icon: "edit"
        accessKey: "V"
        commandScope: row
        accessibleName: qsTr("Exact value for %1").arg(row.label)
        enabled: row.enabled
        onClicked: row.openExact()
    }
    property PromptDialog exactDialog: PromptDialog {
        objectName: "linkedSliderExactDialog"
        parent: row.Window.window ? row.Window.window.contentItem : null
        visible: false
        property real originalValue: NaN
        property real originalPeer: NaN
        readonly property bool current: row.value === originalValue && (row.peerValue === originalPeer || (isNaN(row.peerValue) && isNaN(originalPeer)))
        readonly property real candidate: optionChecked ? 0 : (/^\d+$/.test(inputText) ? Number(inputText) : NaN)
        title: row.label
        icon: "edit"
        inputLabel: row.unit === "%" ? qsTr("Percent") : qsTr("Minutes")
        inputSupportingText: !current ? qsTr("Settings changed. Close and reopen this editor.") : qsTr("Allowed: %1–%2. %3").arg(row.minimumValue).arg(row.maximumValue).arg(row.scaleDescription)
        inputMethodHints: Qt.ImhDigitsOnly
        inputValid: row.valid(candidate)
        optionVisible: row.allowNever
        optionLabel: qsTr("Never")
        onOptionEdited: function(checked) { optionChecked = checked; }
        onInputEdited: function(text) { inputText = text; optionChecked = false; }
        actionsVisible: true
        acceptLabel: qsTr("Save")
        acceptEnabled: row.enabled && current && row.valid(candidate)
        onCancelled: visible = false
        onAccepted: {
            if (!acceptEnabled) return;
            const selected = candidate;
            visible = false;
            row.validationError = "";
            if (selected !== row.value) row.valueSelected(selected);
        }
    }
    FeedbackSource {
        active: row.validationError.length > 0
        text: row.validationError
        summaryText: row.validationError
        tone: "warning"
    }
}
