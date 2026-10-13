pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

// Separate presentation, shared policy/operation owner. Managed idle sleep may
// be unavailable while critical protection remains independently editable.
Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    signal criticalEnableRequested()
    readonly property bool interactive: controller.backend.ready && !controller.suspendPolicySaving && !controller.actionInFlight
    readonly property var criticalPolicy: controller.suspendPolicyDraft.critical_battery || ({
            enabled: false,
            percent: 5,
            grace_seconds: 60
        })
    readonly property var criticalState: controller.suspendPolicyState.critical_battery || ({})
    objectName: "criticalProtectionCard"

    BatterySectionHeading {
        Layout.fillWidth: true
        title: qsTr("Critical protection")
        helpText: qsTr("Warn before hibernating at the selected battery level. Use only one automatic power manager and verify working hibernation before enabling it. Connecting AC or cancelling ends the countdown for this battery episode. An already dispatched request cannot be undone. Locking and inhibitors remain enforced; failures are not retried automatically. Critical protection is independent of managed automatic sleep.")
    }

    Ui.ToggleRow {
        objectName: "criticalBatteryEnabled"
        Layout.fillWidth: true
        compact: true
        wrapTitle: true
        icons: ["shield"]
        title: qsTr("Hibernate at critical battery")
        Accessible.description: qsTr("Warn before hibernating. Use only one automatic power manager. Requires working hibernation.")
        checked: pane.criticalPolicy.enabled
        interactive: pane.interactive
        onClicked: {
            if (checked) pane.controller.updateSuspendPolicy("critical_battery", "enabled", false);
            else pane.criticalEnableRequested();
        }
    }

    Ui.SettingRow {
        Layout.fillWidth: true
        title: qsTr("At or below")
        accessibleName: qsTr("Critical-battery hibernation threshold")
        showHelpButton: false
        compact: true
        visible: pane.criticalPolicy.enabled
        Ui.DropDownList {
            objectName: "criticalBatteryPercent"
            Layout.fillWidth: true
            options: Array.from({
                length: 20
            }, function (_, i) {
                return {
                    value: String(i + 1),
                    label: String(i + 1) + "%"
                };
            })
            value: String(pane.criticalPolicy.percent)
            interactive: pane.interactive && pane.criticalPolicy.enabled
            onSelected: function (value) {
                pane.controller.updateSuspendPolicy("critical_battery", "percent", Number(value));
            }
        }
    }

    Ui.SettingRow {
        Layout.fillWidth: true
        title: qsTr("Warn for")
        accessibleName: qsTr("Critical-battery warning period")
        showHelpButton: false
        compact: true
        visible: pane.criticalPolicy.enabled
        Ui.DropDownList {
            objectName: "criticalBatteryGrace"
            Layout.fillWidth: true
            options: Array.from(new Set([30, 60, 90, 120, 180, 300, pane.criticalPolicy.grace_seconds])).sort(function (a, b) {
                return a - b;
            }).map(function (seconds) {
                return {
                    value: String(seconds),
                    label: qsTr("%1 s").arg(seconds)
                };
            })
            value: String(pane.criticalPolicy.grace_seconds)
            interactive: pane.interactive && pane.criticalPolicy.enabled
            onSelected: function (value) {
                pane.controller.updateSuspendPolicy("critical_battery", "grace_seconds", Number(value));
            }
        }
    }

    Ui.FeedbackSource {
        objectName: "criticalBatteryStatus"
        text: pane.criticalState.error || (pane.criticalState.phase === "countdown" ? qsTr("Hibernation in %1 seconds unless AC connects or you cancel.").arg(pane.criticalState.remaining_seconds) : (["disabled", "armed", "idle"].includes(pane.criticalState.phase || "disabled") ? "" : qsTr("Protection: %1 · locking and inhibitors remain enforced; failures are not retried automatically.").arg(pane.criticalState.phase)))
        summaryText: pane.criticalState.phase === "countdown" ? qsTr("Hibernation in %1s · Connect AC or cancel").arg(pane.criticalState.remaining_seconds) : pane.criticalState.error ? qsTr("Critical protection failed") : qsTr("Protection: %1").arg(pane.criticalState.phase)
        briefText: pane.criticalState.phase === "countdown" ? qsTr("Hibernate in %1s · AC / Cancel").arg(pane.criticalState.remaining_seconds) : summaryText
        tone: "warning"
        priority: 100
    }

    Ui.LabeledAction {
        icon: "cancel"
        objectName: "criticalBatteryCancel"
        accessKey: "C"
        Layout.fillWidth: true
        label: qsTr("Cancel this battery episode")
        accessibleName: qsTr("Cancel critical-battery hibernation")
        enabled: ["countdown", "acting"].includes(pane.criticalState.phase) && !pane.controller.actionInFlight
        toolTip: qsTr("Cancels this battery episode. An already dispatched request cannot be undone.")
        onClicked: pane.controller.cancelCriticalBattery()
    }
}
