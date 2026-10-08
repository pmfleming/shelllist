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
    signal calibrationRequested()
    readonly property bool thresholdsEditable: controller.protectionSupported && !controller.batteryOperationActive && !controller.actionInFlight

    width: parent.width
    spacing: Ui.Theme.spacingMd

    Ui.DetailColumnCard {
        objectName: "batteryProtectionCard"

        BatterySectionHeading {
            Layout.fillWidth: true
            title: qsTr("Charging & protection")
            helpText: qsTr("Resume and stop set the charge limits. The bell follows the effective target, including a one-time full charge. Charging actions: full battery charges to 100% once; pause/play stops or resumes charging; circular arrow calibrates. Health is full capacity divided by design capacity; the cycle icon counts charge cycles.")
        }
        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: !pane.controller.protectionSupported
            text: qsTr("Charge thresholds are not exposed by this battery")
            color: Ui.Theme.warning
        }
        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported && !!pane.protection.managed && !pane.protection.thresholds_verified
            text: qsTr("The firmware accepted the range but reported a different value.")
            color: Ui.Theme.warning
        }
        Ui.ToggleRow {
            objectName: "batteryProtectionEnabled"
            Layout.fillWidth: true
            compact: true
            icons: ["shield"]
            title: qsTr("Protect battery")
            checked: pane.controller.draftProtectionEnabled
            interactive: pane.thresholdsEditable
            onClicked: pane.controller.setProtection(!checked)
        }
        Ui.PercentageSlider {
            objectName: "batteryResumeCharging"
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
            objectName: "batteryStopCharging"
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
            objectName: "batteryThresholdSaveStatus"
            Layout.fillWidth: true
            visible: pane.controller.protectionSupported && (pane.controller.thresholdDraftDirty || pane.controller.thresholdOperationActive || pane.controller.thresholdSaveError.length > 0)
            text: pane.controller.thresholdSaveStatus
            valid: pane.controller.thresholdDraftValid
            error: pane.controller.thresholdSaveError
            saving: pane.controller.thresholdOperationActive
        }
        Ui.ToggleRow {
            objectName: "batteryChargeNotificationToggle"
            readonly property int chargeTarget: pane.protection.enabled && !pane.protection.charge_once_active ? Number(pane.protection.end_percent ?? 100) : 100
            Layout.fillWidth: true
            compact: true
            icons: ["notifications", "arrow_forward"]
            title: chargeTarget + "%"
            accessibleName: qsTr("Notify at charge target (%1%)").arg(chargeTarget)
            checked: pane.controller.alertDraft.notify_when_full
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateNotifyWhenFull(!checked)
        }
        Ui.SaveStatusLabel {
            objectName: "batteryChargeNotificationSaveStatus"
            Layout.fillWidth: true
            visible: pane.controller.alertDraftDirty || pane.controller.alertOperationActive || pane.controller.alertSaveError.length > 0
            text: pane.controller.alertSaveStatus
            valid: pane.controller.alertDraftValid
            error: pane.controller.alertSaveError
            saving: pane.controller.alertOperationActive
        }
        RowLayout {
            Layout.fillWidth: true
            Ui.ThemeText {
                Layout.fillWidth: true
                text: qsTr("Charging actions")
                font.pixelSize: Ui.Theme.fontSizeLabel
                wrapMode: Text.Wrap
            }
            Ui.SurfaceActionRow {
                objectName: "batteryChargingActions"
                Layout.preferredWidth: Math.min(120, pane.width * 0.5)
                headerCommands: false
                compactSecondaryActions: true
                actionObjectNamePrefix: "batteryCareAction-"
                actions: [
                    {
                        id: "once", icon: "battery_charging_full", accessKey: "O",
                        label: pane.protection.charge_once_active ? qsTr("Charging to 100%") : qsTr("Charge to 100% once"),
                        enabled: !!pane.battery.plugged && !pane.protection.charge_once_active && !pane.controller.batteryOperationActive && !pane.controller.thresholdOperationActive && pane.controller.protectionSupported && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar"}
                    },
                    {
                        id: "pause", icon: pane.controller.chargingInhibited ? "play_arrow" : "pause", accessKey: "P",
                        label: pane.controller.chargingInhibited ? qsTr("Resume charging") : qsTr("Pause charging"),
                        enabled: pane.controller.inhibitionSupported && (!pane.controller.batteryOperationActive || pane.controller.chargingInhibited) && !pane.controller.thresholdOperationActive && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar"}
                    },
                    {
                        id: "calibrate", icon: pane.controller.calibrating ? "cancel" : "autorenew", accessKey: "C",
                        label: pane.controller.calibrating ? qsTr("Cancel calibration") : qsTr("Calibrate battery"),
                        enabled: pane.controller.calibrationSupported && (pane.controller.calibrating || !!pane.battery.plugged) && (!pane.controller.batteryOperationActive || pane.controller.calibrating) && !pane.controller.thresholdOperationActive && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar"}
                    }
                ]
                onTriggered: function (actionId) {
                    if (actionId === "once") pane.controller.chargeOnce();
                    else if (actionId === "pause") pane.controller.setChargingInhibited(!pane.controller.chargingInhibited);
                    else if (pane.controller.calibrating) pane.controller.toggleCalibration();
                    else pane.calibrationRequested();
                }
            }
        }
        Ui.FieldLabel {
            objectName: "batteryChargingStatus"
            Layout.fillWidth: true
            visible: pane.controller.calibrating || pane.controller.chargingInhibited || !!pane.protection.charge_once_active
            text: pane.controller.calibrating ? Presentation.calibrationLabel(pane.controller.batteryOperation) : (pane.controller.chargingInhibited ? qsTr("Charging paused") : qsTr("One-time full charge active"))
            color: Ui.Theme.active
        }
    }
}
