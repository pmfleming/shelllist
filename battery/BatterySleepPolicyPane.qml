pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    readonly property bool interactive: controller.sleepPolicyState.available && !controller.sleepPolicySaving && !controller.actionInFlight
    objectName: "automaticSleepCard"
    title: qsTr("Automatic sleep & hibernate")
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
            { value: "ignore", label: qsTr("Do nothing"), enabled: !!(pane.controller.sleepPolicyState.lid || {}).available },
            { value: "lock", label: qsTr("Lock screen"), enabled: !!(pane.controller.sleepPolicyState.lid || {}).available },
            { value: "suspend", label: qsTr("Suspend"), enabled: !!(pane.controller.sleepPolicyState.lid || {}).available },
            { value: "hibernate", label: qsTr("Hibernate immediately"), enabled: !!(pane.controller.sleepPolicyState.lid || {}).available && ["yes", "challenge", "inhibited", "inhibitor-blocked", "challenge-inhibitor-blocked"].includes(pane.controller.powerSleep.can_hibernate) },
            { value: "profile", label: qsTr("Sleep, then hibernate using profile"), enabled: !!(pane.controller.sleepPolicyState.lid || {}).available }
        ]
        value: pane.controller.sleepPolicyDraft.lid_action || "system"
        interactive: pane.interactive
        Accessible.name: qsTr("Action when the laptop lid is closed")
        onSelected: function (value) { pane.controller.updateSleepPolicy("", "lid_action", value); }
    }

    Ui.FieldLabel {
        objectName: "lidCloseStatus"
        Layout.fillWidth: true
        text: (pane.controller.sleepPolicyState.lid || {}).error || qsTr("Managed lid actions ignore docked/external-display use. Profile uses the current power source’s hibernate delay, even when inactivity sleep is Never. System default restores logind’s policy.")
        color: (pane.controller.sleepPolicyState.lid || {}).error ? Ui.Theme.warning : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ToggleRow {
        objectName: "sleepSameProfile"
        Layout.fillWidth: true
        Layout.preferredHeight: 54
        title: qsTr("Use the same settings")
        subtitle: qsTr("On battery and plugged in")
        checked: pane.controller.sleepPolicyDraft.same_profile
        interactive: pane.interactive
        onClicked: pane.controller.updateSleepPolicy("", "same_profile", !checked)
    }

    Repeater {
        model: pane.controller.sleepPolicyDraft.same_profile ? ["battery"] : ["battery", "plugged"]

        delegate: ColumnLayout {
            id: profile
            required property string modelData
            readonly property var settings: pane.controller.sleepPolicyDraft[modelData]
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.ThemeText {
                Layout.fillWidth: true
                text: pane.controller.sleepPolicyDraft.same_profile ? qsTr("Battery & plugged in") : (profile.modelData === "battery" ? qsTr("On battery") : qsTr("Plugged in"))
                font.weight: Ui.Theme.fontWeightDemiBold
                color: pane.controller.sleepPolicyState.active_profile === profile.modelData ? Ui.Theme.accent : Ui.Theme.text
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: qsTr("Sleep after inactivity")
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }

                Ui.DropDownList {
                    objectName: "sleepDelay-" + profile.modelData
                    Layout.preferredWidth: 116
                    options: pane.delayOptions(profile.settings.sleep_minutes)
                    value: String(profile.settings.sleep_minutes)
                    interactive: pane.interactive
                    Accessible.name: qsTr("%1: sleep after inactivity").arg(profile.modelData === "battery" ? qsTr("Battery") : qsTr("Plugged in"))
                    onSelected: function (value) {
                        pane.controller.updateSleepPolicy(profile.modelData, "sleep_minutes", Number(value));
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
                        return Object.assign({}, option, { enabled: option.value === "0" || !!pane.controller.sleepPolicyState.hibernate_available });
                    })
                    value: String(profile.settings.hibernate_minutes)
                    interactive: pane.interactive && (profile.settings.sleep_minutes > 0 || pane.controller.sleepPolicyDraft.lid_action === "profile")
                    Accessible.name: qsTr("%1: time asleep before hibernating").arg(profile.modelData === "battery" ? qsTr("Battery") : qsTr("Plugged in"))
                    onSelected: function (value) {
                        pane.controller.updateSleepPolicy(profile.modelData, "hibernate_minutes", Number(value));
                    }
                }
            }
        }
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        text: qsTr("Hibernate delay is additional time asleep; waking cancels it. Never hibernate keeps ordinary sleep. Low battery may trigger hibernation sooner.")
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.FieldLabel {
        Layout.fillWidth: true
        visible: pane.controller.sleepPolicyState.available && !!pane.controller.sleepPolicyState.hibernate_error
        text: pane.controller.sleepPolicyState.hibernate_error || ""
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.FieldLabel {
        objectName: "sleepPolicyStatus"
        Layout.fillWidth: true
        text: pane.controller.sleepPolicyError || pane.controller.sleepPolicyState.error || pane.controller.sleepPolicyState.last_error || (!pane.controller.sleepPolicyState.available ? qsTr("Automatic sleep requires the managed hypridle integration.") : (pane.controller.sleepPolicySaving ? qsTr("Saving…") : qsTr("Changes apply automatically and restart the inactivity countdown.")))
        color: pane.controller.sleepPolicyError.length > 0 || pane.controller.sleepPolicyState.error || pane.controller.sleepPolicyState.last_error ? Ui.Theme.warning : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.ActionButton {
        objectName: "sleepPolicyRetry"
        Layout.fillWidth: true
        visible: pane.controller.sleepPolicyError.length > 0 && pane.controller.sleepPolicyDirty
        label: qsTr("Retry settings")
        enabled: pane.interactive
        onClicked: pane.controller.saveSleepPolicy()
    }
}
