pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    objectName: "batteryLevelsCard"
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
    title: qsTr("Battery levels & actions")

    Repeater {
        model: ["low", "critical"]

        delegate: ColumnLayout {
            id: level
            required property string modelData
            readonly property bool low: modelData === "low"
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            readonly property var fields: pane.controller.levelFields[modelData]
            readonly property bool active: pane.controller.alertDraft[fields.notify]

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Ui.PercentageSlider {
                    objectName: level.low ? "batteryLowPoint" : "batteryCriticalPoint"
                    Layout.fillWidth: true
                    label: level.low ? qsTr("Low battery") : qsTr("Critical battery")
                    labelWidth: 120
                    valueWidth: 40
                    value: pane.controller.alertDraft[level.fields.percent]
                    enabled: level.active && !pane.controller.actionInFlight
                    onEdited: function (dragging) {
                        if (level.low)
                            pane.controller.updateWarningPercent(Math.round(value), dragging);
                        else
                            pane.controller.updateCriticalPercent(Math.round(value), dragging);
                    }
                    onEditingFinished: pane.controller.finishAlertEditing()
                }

                Ui.ToggleSwitch {
                    objectName: level.low ? "batteryLowEnabled" : "batteryCriticalEnabled"
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 36
                    checked: level.active
                    enabled: !pane.controller.actionInFlight
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: level.low ? qsTr("Low battery") : qsTr("Critical battery")
                    Accessible.description: qsTr("Enable the threshold notification and automatic power profile")
                    Accessible.checkable: true
                    Accessible.checked: checked
                    onToggled: function (checked) {
                        pane.controller.updateLevelEnabled(level.modelData, checked);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Item {
                    Layout.fillWidth: true
                }

                BatteryProfileSelector {
                    objectName: level.low ? "batteryLowProfile" : "batteryCriticalProfile"
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    accessibleName: level.low ? qsTr("Low battery power profile") : qsTr("Critical battery power profile")
                    options: pane.controller.levelProfileOptions
                    value: pane.controller.alertDraft[level.fields.profile]
                    interactive: level.active && !pane.controller.actionInFlight
                    onSelected: function (value) {
                        pane.controller.updateLevelProfile(level.modelData, value);
                    }
                }
            }
        }
    }

    Ui.ThemeText {
        Layout.fillWidth: true
        visible: !pane.controller.alertDraftValid
        text: qsTr("Critical percentage cannot exceed the low-battery percentage.")
        color: Ui.Theme.danger
        font.pixelSize: Ui.Theme.fontSizeCaption
        wrapMode: Text.Wrap
    }

    Ui.SaveStatusLabel {
        objectName: "batteryLevelsSaveStatus"
        Layout.fillWidth: true
        visible: pane.controller.alertDraftDirty || pane.controller.alertOperationActive || pane.controller.alertSaveError.length > 0
        text: pane.controller.alertSaveStatus
        valid: pane.controller.alertDraftValid
        error: pane.controller.alertSaveError
        saving: pane.controller.alertOperationActive
    }

    Ui.FieldLabel {
        objectName: "batteryAutomationStatus"
        Layout.fillWidth: true
        visible: ["paused", "blocked", "unavailable", "error"].indexOf(pane.controller.batteryAutomation.status) >= 0
        text: pane.controller.automationStatus
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        color: pane.controller.batteryAutomation.status === "error" ? Ui.Theme.danger : Ui.Theme.mutedText
    }

    Ui.ActionButton {
        objectName: "batteryAutomationResume"
        Layout.fillWidth: true
        visible: pane.controller.batteryAutomation.status === "paused"
        label: qsTr("Resume automatic switching")
        enabled: pane.controller.powerProfile.available && !pane.controller.actionInFlight
        onClicked: pane.controller.resumeAutomaticProfiles()
    }
}
