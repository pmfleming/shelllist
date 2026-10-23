pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Column {
    id: pane

    required property BatteryController controller
    readonly property BatterySettings settings: controller.settings
    required property var battery
    required property var device
    required property var protection
    signal calibrationRequested()
    readonly property bool thresholdsEditable: controller.protectionSupported && !controller.batteryOperationActive && !settings.thresholdOperationActive && !controller.actionInFlight

    width: parent.width
    spacing: Ui.Theme.spacingMd

    Ui.DetailColumnCard {
        objectName: "batteryProtectionCard"

        BatterySectionHeading {
            Layout.fillWidth: true
            title: qsTr("Charging & protection")
            helpText: qsTr("Resume must be below stop. Both sliders use the same non-linear scale: 50–75% in five-point steps, then one-point steps to 100%. Alt+V enters any supported exact percentage, including values below 50%. Hatching marks unavailable choices; the thin line marks the other threshold. Resume and stop set the charge limits. The bell follows the effective target, including a one-time full charge. Charging actions: full battery charges to 100% once; pause/play stops or resumes charging; circular arrow calibrates. Health is full capacity divided by design capacity; the cycle icon counts charge cycles.")
        }
        Ui.FeedbackSource {
            active: !pane.controller.protectionSupported
            text: qsTr("Charge thresholds are not exposed by this battery")
            summaryText: qsTr("Charge thresholds unsupported")
            tone: "warning"
        }
        Ui.FeedbackSource {
            active: pane.controller.protectionSupported && !!pane.protection.managed && !pane.protection.thresholds_verified
            text: qsTr("The firmware accepted the range but reported a different value.")
            summaryText: qsTr("Charge range differs from request")
            tone: "warning"
        }
        Ui.ToggleRow {
            objectName: "batteryProtectionEnabled"
            Layout.fillWidth: true
            compact: true
            icons: ["shield"]
            title: qsTr("Protect battery")
            checked: pane.settings.draftProtectionEnabled
            interactive: pane.thresholdsEditable
            onClicked: pane.settings.setProtection(!checked)
        }
        Ui.LinkedValueSlider {
            objectName: "batteryResumeCharging"
            Layout.fillWidth: true
            label: qsTr("Resume charging")
            from: 0
            to: 100
            scaleValues: Ui.SliderScale.chargeValues()
            minimumValue: 0
            maximumValue: pane.settings.draftEndPercent - 1
            peerValue: pane.settings.draftEndPercent
            value: pane.settings.draftStartPercent
            interactive: pane.thresholdsEditable
            onValueSelected: function (selectedValue) {
                pane.settings.updateStartPercent(selectedValue, false);
            }
        }
        Ui.LinkedValueSlider {
            objectName: "batteryStopCharging"
            Layout.fillWidth: true
            label: qsTr("Stop charging")
            from: 0
            to: 100
            scaleValues: Ui.SliderScale.chargeValues()
            minimumValue: pane.settings.draftStartPercent + 1
            maximumValue: 100
            peerValue: pane.settings.draftStartPercent
            value: pane.settings.draftEndPercent
            interactive: pane.thresholdsEditable
            onValueSelected: function (selectedValue) {
                pane.settings.updateEndPercent(selectedValue, false);
            }
        }
        Ui.FeedbackSource {
            active: !pane.settings.thresholdDraftValid
            text: qsTr("Resume charging must be lower than stop charging.")
            summaryText: qsTr("Resume must be below stop")
            tone: "error"
        }
        Ui.SaveStatusLabel {
            objectName: "batteryThresholdSaveStatus"
            Layout.fillWidth: true
            active: pane.controller.protectionSupported && (pane.settings.thresholdDraftDirty || pane.settings.thresholdOperationActive || pane.settings.thresholdSaveError.length > 0)
            text: pane.settings.thresholdSaveStatus
            valid: pane.settings.thresholdDraftValid
            error: pane.settings.thresholdSaveError
            saving: pane.settings.thresholdOperationActive
        }
        Ui.ToggleRow {
            objectName: "batteryChargeNotificationToggle"
            readonly property int chargeTarget: pane.protection.enabled && !pane.protection.charge_once_active ? Number(pane.protection.end_percent ?? 100) : 100
            Layout.fillWidth: true
            compact: true
            icons: ["notifications", "arrow_forward"]
            title: chargeTarget + "%"
            accessibleName: qsTr("Notify at charge target (%1%)").arg(chargeTarget)
            checked: pane.settings.alertDraft.notify_when_full
            interactive: !pane.controller.actionInFlight
            onClicked: pane.settings.updateNotifyWhenFull(!checked)
        }
        Ui.SaveStatusLabel {
            objectName: "batteryChargeNotificationSaveStatus"
            Layout.fillWidth: true
            active: pane.settings.alertDraftDirty || pane.settings.alertOperationActive || pane.settings.alertSaveError.length > 0
            text: pane.settings.alertSaveStatus
            valid: pane.settings.alertDraftValid
            error: pane.settings.alertSaveError
            saving: pane.settings.alertOperationActive
        }
        RowLayout {
            objectName: "batteryChargingActionRow"
            Layout.fillWidth: true
            Layout.topMargin: Ui.Theme.spacingSm
            Ui.SectionLabel {
                text: qsTr("Charging actions")
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
                        enabled: !!pane.battery.plugged && !pane.protection.charge_once_active && !pane.controller.batteryOperationActive && !pane.settings.thresholdOperationActive && pane.controller.protectionSupported && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar", iconColor: Ui.Theme.mix(Ui.Theme.text, Qt.color(Presentation.profileTint("power-saver")), 0.35)}
                    },
                    {
                        id: "pause", icon: pane.controller.chargingInhibited ? "play_arrow" : "pause", accessKey: "P",
                        label: pane.controller.chargingInhibited ? qsTr("Resume charging") : qsTr("Pause charging"),
                        enabled: pane.controller.inhibitionSupported && (!pane.controller.batteryOperationActive || pane.controller.chargingInhibited) && !pane.settings.thresholdOperationActive && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar", iconColor: Ui.Theme.mix(Ui.Theme.text, Qt.color(Presentation.profileTint("performance")), 0.35)}
                    },
                    {
                        id: "calibrate", icon: pane.controller.calibrating ? "cancel" : "autorenew", accessKey: "C",
                        label: pane.controller.calibrating ? qsTr("Cancel calibration") : qsTr("Calibrate battery"),
                        enabled: pane.controller.calibrationSupported && (pane.controller.calibrating || !!pane.battery.plugged) && (!pane.controller.batteryOperationActive || pane.controller.calibrating) && !pane.settings.thresholdOperationActive && !pane.controller.actionInFlight,
                        presentation: {group: "toolbar", iconColor: Ui.Theme.mix(Ui.Theme.text, Qt.color(Presentation.profileTint("balanced")), 0.35)}
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
        Ui.FeedbackSource {
            objectName: "batteryChargingStatus"
            active: pane.controller.calibrating || pane.controller.chargingInhibited || !!pane.protection.charge_once_active
            text: pane.controller.calibrating ? Presentation.calibrationLabel(pane.controller.batteryOperation) : (pane.controller.chargingInhibited ? qsTr("Charging paused") : qsTr("One-time full charge active"))
            summaryText: pane.controller.calibrating ? qsTr("Calibration in progress") : text
        }
    }
}
