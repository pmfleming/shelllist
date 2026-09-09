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

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("While unplugged · critical settings take priority")
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Repeater {
        model: ["low", "critical"]

        delegate: ColumnLayout {
            id: level
            required property string modelData
            readonly property bool low: modelData === "low"
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.PercentageSlider {
                objectName: level.low ? "batteryLowPoint" : "batteryCriticalPoint"
                Layout.fillWidth: true
                label: level.low ? qsTr("Low battery") : qsTr("Critical battery")
                value: level.low ? pane.controller.draftWarningPercent : pane.controller.draftCriticalPercent
                enabled: !pane.controller.actionInFlight
                onEdited: function (dragging) {
                    if (level.low)
                        pane.controller.updateWarningPercent(Math.round(value), dragging);
                    else
                        pane.controller.updateCriticalPercent(Math.round(value), dragging);
                }
                onEditingFinished: pane.controller.finishAlertEditing()
            }

            Ui.ToggleRow {
                objectName: level.low ? "batteryLowNotify" : "batteryCriticalNotify"
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                title: qsTr("Notify")
                subtitle: qsTr("Once when this battery level is reached")
                checked: level.low ? pane.controller.draftNotifyWarning : pane.controller.draftNotifyCritical
                interactive: !pane.controller.actionInFlight
                onClicked: pane.controller.updateLevelNotification(level.modelData, !checked)
            }

            Ui.FieldLabel {
                Layout.fillWidth: true
                text: qsTr("Power profile")
            }

            Ui.SegmentedControl {
                objectName: level.low ? "batteryLowProfile" : "batteryCriticalProfile"
                Layout.fillWidth: true
                Layout.preferredHeight: Ui.Theme.compactControlHeight
                options: pane.controller.levelProfileOptions
                value: level.low ? pane.controller.draftWarningProfile : pane.controller.draftCriticalProfile
                interactive: !pane.controller.actionInFlight
                onSelected: function (value) {
                    pane.controller.updateLevelProfile(level.modelData, value);
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

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("Recovery margin: %1 percentage points. Plugging in releases our profile override.").arg(pane.controller.valueOr(pane.controller.policy.recovery_margin_percent, 3))
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.SaveStatusLabel {
        Layout.fillWidth: true
        text: pane.controller.alertSaveStatus
        valid: pane.controller.alertDraftValid
        error: pane.controller.alertSaveError
        saving: pane.controller.alertOperationActive
    }

    Ui.FieldLabel {
        objectName: "batteryAutomationStatus"
        Layout.fillWidth: true
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
