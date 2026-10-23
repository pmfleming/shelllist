pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    readonly property BatterySettings settings: controller.settings
    objectName: "batteryLevelsCard"

    BatterySectionHeading {
        Layout.fillWidth: true
        title: qsTr("Battery levels & actions")
        helpText: qsTr("Each enabled level notifies and can select an automatic power profile: leaf is Power saver, sliders are Balanced, lightning is Performance. These notification thresholds are separate from critical-battery hibernation.")
    }

    Repeater {
        model: ["low", "critical"]

        delegate: ColumnLayout {
            id: level
            required property string modelData
            readonly property bool low: modelData === "low"
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            readonly property var fields: pane.settings.levelFields[modelData]
            readonly property bool active: pane.settings.alertDraft[fields.notify]

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Ui.PercentageSlider {
                    objectName: level.low ? "batteryLowPoint" : "batteryCriticalPoint"
                    Layout.fillWidth: true
                    label: level.low ? qsTr("Low battery") : qsTr("Critical battery")
                    valueWidth: 40
                    value: pane.settings.alertDraft[level.fields.percent]
                    enabled: level.active && !pane.controller.actionInFlight
                    onEdited: function (dragging) {
                        if (level.low)
                            pane.settings.updateWarningPercent(Math.round(value), dragging);
                        else
                            pane.settings.updateCriticalPercent(Math.round(value), dragging);
                    }
                    onEditingFinished: pane.settings.finishAlertEditing()
                }

                Ui.ToggleSwitch {
                    objectName: level.low ? "batteryLowEnabled" : "batteryCriticalEnabled"
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    checked: level.active
                    enabled: !pane.controller.actionInFlight
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: level.low ? qsTr("Low battery") : qsTr("Critical battery")
                    Accessible.description: qsTr("Enable the threshold notification and automatic power profile")
                    Accessible.checkable: true
                    Accessible.checked: checked
                    onToggled: function (checked) {
                        pane.settings.updateLevelEnabled(level.modelData, checked);
                    }
                }
            }

            Ui.FormField {
                Layout.fillWidth: true
                label: level.low ? qsTr("Low battery profile") : qsTr("Critical battery profile")
                BatteryProfileSelector {
                    objectName: level.low ? "batteryLowProfile" : "batteryCriticalProfile"
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    accessibleName: level.low ? qsTr("Low battery power profile") : qsTr("Critical battery power profile")
                    options: pane.controller.levelProfileOptions
                    value: pane.settings.alertDraft[level.fields.profile]
                    interactive: level.active && !pane.controller.actionInFlight
                    onSelected: function (value) {
                        pane.settings.updateLevelProfile(level.modelData, value);
                    }
                }
            }
        }
    }

    Ui.FeedbackSource {
        active: !pane.settings.alertDraftValid
        text: qsTr("Critical percentage cannot exceed the low-battery percentage.")
        summaryText: qsTr("Critical level must not exceed low")
        tone: "error"
    }

    Ui.SaveStatusLabel {
        objectName: "batteryLevelsSaveStatus"
        Layout.fillWidth: true
        active: pane.settings.alertDraftDirty || pane.settings.alertOperationActive || pane.settings.alertSaveError.length > 0
        text: pane.settings.alertSaveStatus
        valid: pane.settings.alertDraftValid
        error: pane.settings.alertSaveError
        saving: pane.settings.alertOperationActive
    }

    Ui.FeedbackSource {
        objectName: "batteryAutomationStatus"
        active: ["paused", "blocked", "unavailable", "error"].indexOf(pane.controller.batteryAutomation.status) >= 0
        text: pane.controller.automationStatus
        summaryText: qsTr("Battery automation: %1").arg(pane.controller.batteryAutomation.status)
        tone: pane.controller.batteryAutomation.status === "error" ? "error" : "info"
    }

    Ui.LabeledAction {
        icon: "autorenew"
        objectName: "batteryAutomationResume"
        accessKey: "A"
        Layout.fillWidth: true
        label: qsTr("Resume automatic switching")
        enabled: pane.controller.batteryAutomation.status === "paused" && pane.controller.powerProfile.available && !pane.controller.actionInFlight
        onClicked: pane.controller.resumeAutomaticProfiles()
    }
}
