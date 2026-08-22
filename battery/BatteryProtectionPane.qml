pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Column {
    id: pane

    required property BatteryController controller
    required property var battery
    required property var device
    required property var protection

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        height: 450
        title: "ThinkPad battery protection"

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: !pane.controller.protectionSupported
                ? "Charge thresholds are not exposed by this battery"
                : (pane.protection.managed
                    ? "Managed by bar-daemon · observed "
                        + Presentation.protectionRange(pane.protection)
                    : "Observed " + Presentation.protectionRange(pane.protection)
                        + " · not managed yet")
            color: pane.controller.protectionSupported
                ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported
                && pane.protection.managed
                && !pane.protection.thresholds_verified
            text: "The firmware accepted the range but reported a different value."
            color: Ui.Theme.warning
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: "Protect battery longevity"
            subtitle: "Keep charging within the configured threshold range"
            checked: pane.controller.draftProtectionEnabled
            interactive: pane.controller.protectionSupported
                && !pane.controller.batteryOperationActive
                && !pane.controller.actionInFlight
            onClicked: pane.controller.setProtection(!checked)
        }

        Ui.LabeledValueSlider {
            Layout.fillWidth: true
            label: "Resume charging"
            from: 0
            to: 99
            stepSize: 1
            value: pane.controller.draftStartPercent
            valueText: Math.round(value) + "%"
            enabled: pane.controller.protectionSupported
                && !pane.controller.batteryOperationActive
                && !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateStartPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishThresholdEditing()
        }

        Ui.LabeledValueSlider {
            Layout.fillWidth: true
            label: "Stop charging"
            from: 1
            to: 100
            stepSize: 1
            value: pane.controller.draftEndPercent
            valueText: Math.round(value) + "%"
            enabled: pane.controller.protectionSupported
                && !pane.controller.batteryOperationActive
                && !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateEndPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishThresholdEditing()
        }

        Text {
            Layout.fillWidth: true
            visible: !pane.controller.thresholdDraftValid
            text: "Resume charging must be lower than stop charging."
            color: Ui.Theme.danger
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported
            text: pane.controller.thresholdSaveStatus
            color: !pane.controller.thresholdDraftValid
                    || pane.controller.thresholdSaveError.length > 0
                ? Ui.Theme.danger
                : (pane.controller.thresholdOperationActive
                    ? Ui.Theme.active : Ui.Theme.mutedText)
        }

        Ui.ActionButton {
            Layout.fillWidth: true
            label: pane.protection.charge_once_active
                ? "Charging to 100%" : "Charge to 100% once"
            tone: pane.protection.charge_once_active ? "active" : "normal"
            enabled: pane.battery.plugged
                && !pane.protection.charge_once_active
                && !pane.controller.batteryOperationActive
                && !pane.controller.thresholdOperationActive
                && pane.controller.protectionSupported
                && !pane.controller.actionInFlight
            onClicked: pane.controller.chargeOnce()
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: pane.controller.calibrating
            text: Presentation.calibrationLabel(pane.controller.batteryOperation)
            color: Ui.Theme.active
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.ActionButton {
                Layout.fillWidth: true
                label: pane.controller.chargingInhibited
                    ? "Resume charging" : "Pause charging"
                tone: pane.controller.chargingInhibited ? "active" : "normal"
                enabled: pane.controller.inhibitionSupported
                    && (!pane.controller.batteryOperationActive
                        || pane.controller.chargingInhibited)
                    && !pane.controller.thresholdOperationActive
                    && !pane.controller.actionInFlight
                onClicked: pane.controller.setChargingInhibited(
                    !pane.controller.chargingInhibited)
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: pane.controller.calibrating
                    ? "Cancel calibration" : "Calibrate battery"
                tone: pane.controller.calibrating ? "active" : "normal"
                enabled: pane.controller.calibrationSupported
                    && pane.battery.plugged
                    && (!pane.controller.batteryOperationActive
                        || pane.controller.calibrating)
                    && !pane.controller.thresholdOperationActive
                    && !pane.controller.actionInFlight
                onClicked: pane.controller.toggleCalibration()
            }
        }
    }

    Ui.DetailColumnCard {
        height: 335
        title: "Alerts"

        Ui.LabeledValueSlider {
            Layout.fillWidth: true
            label: "Low battery"
            from: 0
            to: 100
            stepSize: 1
            value: pane.controller.draftWarningPercent
            valueText: Math.round(value) + "%"
            enabled: !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateWarningPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishAlertEditing()
        }

        Ui.LabeledValueSlider {
            Layout.fillWidth: true
            label: "Critical battery"
            from: 0
            to: 100
            stepSize: 1
            value: pane.controller.draftCriticalPercent
            valueText: Math.round(value) + "%"
            enabled: !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateCriticalPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishAlertEditing()
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: "Notify when full"
            subtitle: "Show one notification when charging reaches 100%"
            checked: pane.controller.draftNotifyWhenFull
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateNotifyWhenFull(!checked)
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: "Automatic power saver"
            subtitle: "Hold power saver below the low-battery level"
            checked: pane.controller.draftAutoPowerSaver
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateAutoPowerSaver(!checked)
        }

        Text {
            Layout.fillWidth: true
            visible: !pane.controller.alertDraftValid
            text: "Critical percentage cannot exceed the low-battery percentage."
            color: Ui.Theme.danger
            font.family: Ui.Theme.fontFamily
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.alertSaveStatus
            color: !pane.controller.alertDraftValid
                    || pane.controller.alertSaveError.length > 0
                ? Ui.Theme.danger
                : (pane.controller.alertOperationActive
                    ? Ui.Theme.active : Ui.Theme.mutedText)
        }
    }
}
