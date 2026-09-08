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
    readonly property bool thresholdsEditable: controller.protectionSupported && !controller.batteryOperationActive && !controller.actionInFlight

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        objectName: "batteryProtectionCard"
        verticalContentPadding: Ui.Theme.spacingMd
        headingSpacing: Ui.Theme.spacingMd
        height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
        title: qsTr("Charging & protection")

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: "Applies to " + Presentation.deviceName(pane.device)
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: !pane.controller.protectionSupported ? "Charge thresholds are not exposed by this battery" : (pane.protection.managed ? "Managed by bar-daemon · observed " + Presentation.protectionRange(pane.protection) : "Observed " + Presentation.protectionRange(pane.protection) + " · not managed yet")
            color: pane.controller.protectionSupported ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported && !!pane.protection.managed && !pane.protection.thresholds_verified
            text: qsTr("The firmware accepted the range but reported a different value.")
            color: Ui.Theme.warning
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: qsTr("Protect battery longevity")
            subtitle: qsTr("Keep charging within the configured threshold range")
            checked: pane.controller.draftProtectionEnabled
            interactive: pane.thresholdsEditable
            onClicked: pane.controller.setProtection(!checked)
        }

        Ui.PercentageSlider {
            Layout.fillWidth: true
            label: qsTr("Resume charging")
            to: 99
            value: pane.controller.draftStartPercent
            enabled: pane.thresholdsEditable
            onEdited: function (dragging) {
                pane.controller.updateStartPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishThresholdEditing()
        }

        Ui.PercentageSlider {
            Layout.fillWidth: true
            label: qsTr("Stop charging")
            from: 1
            value: pane.controller.draftEndPercent
            enabled: pane.thresholdsEditable
            onEdited: function (dragging) {
                pane.controller.updateEndPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishThresholdEditing()
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            visible: !pane.controller.thresholdDraftValid
            text: qsTr("Resume charging must be lower than stop charging.")
            color: Ui.Theme.danger
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        Ui.SaveStatusLabel {
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported
            text: pane.controller.thresholdSaveStatus
            valid: pane.controller.thresholdDraftValid
            error: pane.controller.thresholdSaveError
            saving: pane.controller.thresholdOperationActive
        }

        Ui.ActionButton {
            Layout.fillWidth: true
            label: pane.protection.charge_once_active ? "Charging to 100%" : "Charge to 100% once"
            tone: pane.protection.charge_once_active ? "active" : "normal"
            enabled: !!pane.battery.plugged && !pane.protection.charge_once_active && !pane.controller.batteryOperationActive && !pane.controller.thresholdOperationActive && pane.controller.protectionSupported && !pane.controller.actionInFlight
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
                label: pane.controller.chargingInhibited ? "Resume charging" : "Pause charging"
                tone: pane.controller.chargingInhibited ? "active" : "normal"
                enabled: pane.controller.inhibitionSupported && (!pane.controller.batteryOperationActive || pane.controller.chargingInhibited) && !pane.controller.thresholdOperationActive && !pane.controller.actionInFlight
                onClicked: pane.controller.setChargingInhibited(!pane.controller.chargingInhibited)
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: pane.controller.calibrating ? "Cancel calibration" : "Calibrate battery"
                tone: pane.controller.calibrating ? "active" : "normal"
                enabled: pane.controller.calibrationSupported && (pane.controller.calibrating || !!pane.battery.plugged) && (!pane.controller.batteryOperationActive || pane.controller.calibrating) && !pane.controller.thresholdOperationActive && !pane.controller.actionInFlight
                onClicked: pane.controller.toggleCalibration()
            }
        }
    }

    Ui.DetailColumnCard {
        objectName: "batteryAlertsCard"
        verticalContentPadding: Ui.Theme.spacingMd
        headingSpacing: Ui.Theme.spacingMd
        height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
        title: qsTr("Battery alerts")

        Ui.PercentageSlider {
            Layout.fillWidth: true
            label: qsTr("Low battery")
            value: pane.controller.draftWarningPercent
            enabled: !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateWarningPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishAlertEditing()
        }

        Ui.PercentageSlider {
            Layout.fillWidth: true
            label: qsTr("Critical battery")
            value: pane.controller.draftCriticalPercent
            enabled: !pane.controller.actionInFlight
            onEdited: function (dragging) {
                pane.controller.updateCriticalPercent(Math.round(value), dragging);
            }
            onEditingFinished: pane.controller.finishAlertEditing()
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: qsTr("Notify when full")
            subtitle: qsTr("Notify at the charge limit, or 100% when unprotected")
            checked: pane.controller.draftNotifyWhenFull
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateNotifyWhenFull(!checked)
        }

        Ui.ThemeText {
            Layout.fillWidth: true
            visible: !pane.controller.alertDraftValid
            text: qsTr("Critical percentage cannot exceed the low-battery percentage.")
            color: Ui.Theme.danger
            font.pixelSize: Ui.Theme.fontSizeCaption
        }

        Ui.SaveStatusLabel {
            Layout.fillWidth: true
            text: pane.controller.alertSaveStatus
            valid: pane.controller.alertDraftValid
            error: pane.controller.alertSaveError
            saving: pane.controller.alertOperationActive
        }
    }
}
