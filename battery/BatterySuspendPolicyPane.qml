pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    readonly property bool interactive: controller.suspendPolicyState.available && !controller.suspendPolicySaving && !controller.actionInFlight
    readonly property bool criticalInteractive: controller.backend.ready && !controller.suspendPolicySaving && !controller.actionInFlight
    readonly property var criticalPolicy: controller.suspendPolicyDraft.critical_battery || ({ enabled: false, percent: 5, grace_seconds: 60 })
    readonly property var criticalState: controller.suspendPolicyState.critical_battery || ({})
    objectName: "automaticSuspendCard"
    title: qsTr("Automatic suspend & hibernate")
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding

    function delayOptions(current: int): var {
        const minutes = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720, 1440];
        if (!minutes.includes(current)) {
            minutes.push(current);
            minutes.sort(function (a, b) { return a - b; });
        }
        return minutes.map(function (value) {
            return {
                value: String(value),
                label: value === 0 ? qsTr("Never") : (value >= 60 && value % 60 === 0 ? qsTr("%1 h").arg(value / 60) : qsTr("%1 min").arg(value))
            };
        });
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("When the lid is closed")
    }

    Ui.DropDownList {
        objectName: "lidCloseAction"
        Layout.fillWidth: true
        options: [
            { value: "system", label: qsTr("System default") },
            { value: "ignore", label: qsTr("Do nothing"), enabled: !!(pane.controller.suspendPolicyState.lid || {}).available },
            { value: "lock", label: qsTr("Lock screen"), enabled: !!(pane.controller.suspendPolicyState.lid || {}).available },
            { value: "suspend", label: qsTr("Suspend"), enabled: !!(pane.controller.suspendPolicyState.lid || {}).available },
            { value: "hibernate", label: qsTr("Hibernate immediately"), enabled: !!(pane.controller.suspendPolicyState.lid || {}).available && ["yes", "challenge", "inhibited", "inhibitor-blocked", "challenge-inhibitor-blocked"].includes(pane.controller.powerSuspend.can_hibernate) },
            { value: "profile", label: qsTr("Suspend, then hibernate using profile"), enabled: !!(pane.controller.suspendPolicyState.lid || {}).available }
        ]
        value: pane.controller.suspendPolicyDraft.lid_action || "system"
        interactive: pane.interactive
        Accessible.name: qsTr("Action when the laptop lid is closed")
        onSelected: function (value) { pane.controller.updateSuspendPolicy("", "lid_action", value); }
    }

    Ui.FieldLabel {
        objectName: "lidCloseStatus"
        Layout.fillWidth: true
        text: (pane.controller.suspendPolicyState.lid || {}).error || qsTr("Managed lid actions ignore docked/external-display use. Profile uses the current power source’s hibernate delay, even when inactivity suspend is Never. System default restores logind’s policy.")
        color: (pane.controller.suspendPolicyState.lid || {}).error ? Ui.Theme.warning : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ToggleRow {
        objectName: "suspendSameProfile"
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        title: qsTr("Use the same settings")
        subtitle: qsTr("On battery and plugged in")
        checked: pane.controller.suspendPolicyDraft.same_profile
        interactive: pane.interactive
        onClicked: pane.controller.updateSuspendPolicy("", "same_profile", !checked)
    }

    Repeater {
        model: pane.controller.suspendPolicyDraft.same_profile ? ["battery"] : ["battery", "plugged"]

        delegate: ColumnLayout {
            id: profile
            required property string modelData
            readonly property var settings: pane.controller.suspendPolicyDraft[modelData]
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.ThemeText {
                Layout.fillWidth: true
                text: pane.controller.suspendPolicyDraft.same_profile ? qsTr("Battery & plugged in") : (profile.modelData === "battery" ? qsTr("On battery") : qsTr("Plugged in"))
                font.weight: Ui.Theme.fontWeightDemiBold
                color: pane.controller.suspendPolicyState.active_profile === profile.modelData ? Ui.Theme.accent : Ui.Theme.text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: qsTr("Suspend after inactivity")
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Ui.DropDownList {
                    objectName: "suspendDelay-" + profile.modelData
                    Layout.preferredWidth: 116
                    options: pane.delayOptions(profile.settings.sleep_minutes)
                    value: String(profile.settings.sleep_minutes)
                    interactive: pane.interactive
                    Accessible.name: qsTr("%1: suspend after inactivity").arg(profile.modelData === "battery" ? qsTr("Battery") : qsTr("Plugged in"))
                    onSelected: function (value) {
                        pane.controller.updateSuspendPolicy(profile.modelData, "sleep_minutes", Number(value));
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: qsTr("Then hibernate after")
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Ui.DropDownList {
                    objectName: "hibernateDelay-" + profile.modelData
                    Layout.preferredWidth: 116
                    options: pane.delayOptions(profile.settings.hibernate_minutes).map(function (option) {
                        return Object.assign({}, option, { enabled: option.value === "0" || !!pane.controller.suspendPolicyState.hibernate_available });
                    })
                    value: String(profile.settings.hibernate_minutes)
                    interactive: pane.interactive && (profile.settings.sleep_minutes > 0 || pane.controller.suspendPolicyDraft.lid_action === "profile")
                    Accessible.name: qsTr("%1: time suspended before hibernating").arg(profile.modelData === "battery" ? qsTr("Battery") : qsTr("Plugged in"))
                    onSelected: function (value) {
                        pane.controller.updateSuspendPolicy(profile.modelData, "hibernate_minutes", Number(value));
                    }
                }
            }
        }
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("Hibernate delay is additional time suspended; waking cancels it. Never hibernate keeps ordinary suspend. Low battery may trigger hibernation sooner.")
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        visible: pane.controller.suspendPolicyState.available && !!pane.controller.suspendPolicyState.hibernate_error
        text: pane.controller.suspendPolicyState.hibernate_error || ""
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ToggleRow {
        objectName: "criticalBatteryEnabled"
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        title: qsTr("Critical-battery hibernation")
        subtitle: qsTr("Opt-in awake protection · do not enable a second power manager")
        checked: pane.criticalPolicy.enabled
        interactive: pane.criticalInteractive
        onClicked: pane.controller.updateSuspendPolicy("critical_battery", "enabled", !checked)
    }

    RowLayout {
        Layout.fillWidth: true
        Ui.FieldLabel { Layout.fillWidth: true; text: qsTr("Hibernate at or below") }
        Ui.DropDownList {
            objectName: "criticalBatteryPercent"
            Layout.preferredWidth: 116
            options: Array.from({ length: 20 }, function (_, i) { return { value: String(i + 1), label: String(i + 1) + "%" }; })
            value: String(pane.criticalPolicy.percent)
            interactive: pane.criticalInteractive && pane.criticalPolicy.enabled
            Accessible.name: qsTr("Critical-battery hibernation threshold")
            onSelected: function (value) { pane.controller.updateSuspendPolicy("critical_battery", "percent", Number(value)); }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Ui.FieldLabel { Layout.fillWidth: true; text: qsTr("Warning period") }
        Ui.DropDownList {
            objectName: "criticalBatteryGrace"
            Layout.preferredWidth: 116
            options: Array.from(new Set([30, 60, 90, 120, 180, 300, pane.criticalPolicy.grace_seconds])).sort(function (a, b) { return a - b; }).map(function (seconds) { return { value: String(seconds), label: qsTr("%1 s").arg(seconds) }; })
            value: String(pane.criticalPolicy.grace_seconds)
            interactive: pane.criticalInteractive && pane.criticalPolicy.enabled
            Accessible.name: qsTr("Critical-battery warning period")
            onSelected: function (value) { pane.controller.updateSuspendPolicy("critical_battery", "grace_seconds", Number(value)); }
        }
    }

    Ui.FieldLabel {
        objectName: "criticalBatteryStatus"
        Layout.fillWidth: true
        text: pane.criticalState.error || (pane.criticalState.phase === "countdown"
            ? qsTr("Hibernation in %1 seconds unless AC connects or you cancel.").arg(pane.criticalState.remaining_seconds)
            : qsTr("State: %1. Requires working hibernation. Locking and inhibitors remain enforced; failures are not retried automatically.").arg(pane.criticalState.phase || "disabled"))
        color: pane.criticalState.error ? Ui.Theme.warning : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ActionButton {
        objectName: "criticalBatteryCancel"
        Layout.fillWidth: true
        visible: ["countdown", "acting"].includes(pane.criticalState.phase)
        label: qsTr("Cancel critical-battery hibernation")
        enabled: !pane.controller.actionInFlight
        toolTip: qsTr("Cancels this battery episode. An already dispatched request cannot be undone.")
        onClicked: pane.controller.cancelCriticalBattery()
    }

    Ui.FieldLabel {
        objectName: "suspendPolicyStatus"
        Layout.fillWidth: true
        text: pane.controller.suspendPolicyError || pane.controller.suspendPolicyState.error || pane.controller.suspendPolicyState.last_error || (!pane.controller.suspendPolicyState.available ? qsTr("Automatic suspend requires the managed hypridle integration.") : (pane.controller.suspendPolicySaving ? qsTr("Saving…") : qsTr("Changes apply automatically. Only an altered suspend timeout resets its countdown; lock and display timers are preserved.")))
        color: pane.controller.suspendPolicyError.length > 0 || pane.controller.suspendPolicyState.error || pane.controller.suspendPolicyState.last_error ? Ui.Theme.warning : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ActionButton {
        objectName: "suspendPolicyRetry"
        Layout.fillWidth: true
        visible: pane.controller.suspendPolicyError.length > 0 && pane.controller.suspendPolicyDirty
        label: qsTr("Retry settings")
        enabled: pane.controller.suspendPolicyCriticalOnly ? pane.criticalInteractive : pane.interactive
        onClicked: pane.controller.saveSuspendPolicy()
    }
}
