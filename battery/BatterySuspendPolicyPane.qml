pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    property bool errorDetailsOpen: false
    readonly property bool interactive: controller.suspendPolicyState.available && !controller.suspendPolicySaving && !controller.actionInFlight
    readonly property bool criticalInteractive: controller.backend.ready && !controller.suspendPolicySaving && !controller.actionInFlight
    objectName: "automaticSuspendCard"

    BatterySectionHeading {
        Layout.fillWidth: true
        title: qsTr("Automatic sleep")
        helpText: qsTr("Suspend after is measured from inactivity; Then hibernate is measured from suspend. Same settings shares one profile between battery and AC. The lid action is ignored while docked or using an external display; System default delegates to the system. The profile action uses this power source’s hibernate delay, even with inactivity set to Never. Waking cancels delayed hibernation; low battery may hibernate sooner. Keep awake blocks suspend and hibernate, not locking or screen blanking. Use only one automatic power manager.")
    }

    function delayOptions(current: int): var {
        const minutes = [0, 5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240, 360, 480, 720, 1440];
        if (!minutes.includes(current)) {
            minutes.push(current);
            minutes.sort(function (a, b) {
                return a - b;
            });
        }
        return minutes.map(function (value) {
            return {
                value: String(value),
                label: value === 0 ? qsTr("Never") : (value >= 60 && value % 60 === 0 ? qsTr("%1 h").arg(value / 60) : qsTr("%1 min").arg(value))
            };
        });
    }

    Ui.SettingRow {
        Layout.fillWidth: true
        title: qsTr("Lid closed")
        accessibleName: qsTr("Action when the laptop lid is closed")
        showHelpButton: false
        compact: true
        subtitle: (pane.controller.suspendPolicyState.lid || {}).error || ""
        subtitleColor: (pane.controller.suspendPolicyState.lid || {}).error ? Ui.Theme.warning : Ui.Theme.mutedText

        Ui.DropDownList {
            objectName: "lidCloseAction"
            Layout.fillWidth: true
            options: [
                {
                    value: "system",
                    label: qsTr("System default")
                },
                {
                    value: "ignore",
                    label: qsTr("Do nothing"),
                    enabled: !!(pane.controller.suspendPolicyState.lid || {}).available
                },
                {
                    value: "lock",
                    label: qsTr("Lock screen"),
                    enabled: !!(pane.controller.suspendPolicyState.lid || {}).available
                },
                {
                    value: "suspend",
                    label: qsTr("Suspend"),
                    enabled: !!(pane.controller.suspendPolicyState.lid || {}).available
                },
                {
                    value: "hibernate",
                    label: qsTr("Hibernate immediately"),
                    enabled: !!(pane.controller.suspendPolicyState.lid || {}).available && ["yes", "challenge", "inhibited", "inhibitor-blocked", "challenge-inhibitor-blocked"].includes(pane.controller.powerSuspend.can_hibernate)
                },
                {
                    value: "profile",
                    label: qsTr("Suspend, then hibernate using profile"),
                    enabled: !!(pane.controller.suspendPolicyState.lid || {}).available
                }
            ]
            value: pane.controller.suspendPolicyDraft.lid_action || "system"
            interactive: pane.interactive
            onSelected: function (value) {
                pane.controller.updateSuspendPolicy("", "lid_action", value);
            }
        }
    }

    Ui.ToggleRow {
        objectName: "suspendSameProfile"
        Layout.fillWidth: true
        Layout.preferredHeight: implicitHeight
        compact: true
        title: qsTr("Same settings on battery & AC")
        accessibleName: qsTr("Use the same sleep settings on battery and plugged in")
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
            readonly property string sourceName: pane.controller.suspendPolicyDraft.same_profile ? qsTr("Battery & plugged in") : (modelData === "battery" ? qsTr("On battery") : qsTr("Plugged in"))
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: Ui.Theme.spacingSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Ui.Theme.spacingSm

                Repeater {
                    model: pane.controller.suspendPolicyDraft.same_profile ? ["battery_full", "power"] : [profile.modelData === "battery" ? "battery_full" : "power"]
                    delegate: Ui.GlyphLabel {
                        required property string modelData
                        glyph: modelData
                        color: Ui.Theme.mutedText
                        font.pixelSize: Ui.Theme.iconSize
                        Accessible.ignored: true
                    }
                }
                Ui.ThemeText {
                    objectName: "suspendProfileHeading-" + profile.modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    text: profile.sourceName
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    color: Ui.Theme.mutedText
                    wrapMode: Text.Wrap
                }
                Ui.ThemeText {
                    objectName: "suspendProfileCurrent-" + profile.modelData
                    visible: ["battery", "plugged"].includes(pane.controller.suspendPolicyState.active_profile || "") && (pane.controller.suspendPolicyDraft.same_profile || pane.controller.suspendPolicyState.active_profile === profile.modelData)
                    text: qsTr("Current")
                    font.pixelSize: Ui.Theme.fontSizeLabel
                    color: Ui.Theme.accent
                }
            }

            Ui.SettingRow {
                Layout.fillWidth: true
                title: qsTr("Suspend after")
                accessibleName: qsTr("%1: suspend after inactivity").arg(profile.sourceName)
                showHelpButton: false
                compact: true

                Ui.DropDownList {
                    objectName: "suspendDelay-" + profile.modelData
                    Layout.fillWidth: true
                    options: pane.delayOptions(profile.settings.sleep_minutes)
                    value: String(profile.settings.sleep_minutes)
                    interactive: pane.interactive
                    onSelected: function (value) {
                        pane.controller.updateSuspendPolicy(profile.modelData, "sleep_minutes", Number(value));
                    }
                }
            }

            Ui.SettingRow {
                Layout.fillWidth: true
                title: qsTr("Then hibernate")
                accessibleName: qsTr("%1: time suspended before hibernating").arg(profile.sourceName)
                showHelpButton: false
                compact: true

                Ui.DropDownList {
                    objectName: "hibernateDelay-" + profile.modelData
                    Layout.fillWidth: true
                    options: pane.delayOptions(profile.settings.hibernate_minutes).map(function (option) {
                        return Object.assign({}, option, {
                            enabled: option.value === "0" || !!pane.controller.suspendPolicyState.hibernate_available
                        });
                    })
                    value: String(profile.settings.hibernate_minutes)
                    interactive: pane.interactive && (profile.settings.sleep_minutes > 0 || pane.controller.suspendPolicyDraft.lid_action === "profile")
                    onSelected: function (value) {
                        pane.controller.updateSuspendPolicy(profile.modelData, "hibernate_minutes", Number(value));
                    }
                }
            }
        }
    }

    Ui.FeedbackSource {
        active: pane.controller.suspendPolicyState.available && !!pane.controller.suspendPolicyState.hibernate_error
        text: pane.controller.suspendPolicyState.hibernate_error || ""
        summaryText: qsTr("Hibernation unavailable")
        tone: "warning"
    }

    Ui.FeedbackSource {
        objectName: "suspendPolicyStatus"
        text: pane.controller.suspendPolicyError || (pane.controller.suspendPolicyState.error || pane.controller.suspendPolicyState.last_error || !pane.controller.suspendPolicyState.available ? qsTr("Automatic sleep unavailable") : (pane.controller.suspendPolicySaving ? qsTr("Saving…") : ""))
        summaryText: pane.controller.suspendPolicySaving ? qsTr("Saving sleep settings…") : qsTr("Automatic sleep needs attention")
        tone: pane.controller.suspendPolicyError.length > 0 || pane.controller.suspendPolicyState.error || pane.controller.suspendPolicyState.last_error ? "warning" : "info"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingSm
        Item { Layout.fillWidth: true }
        Ui.FlatIconButton {
            objectName: "suspendPolicyDetails"
            Layout.preferredWidth: Ui.Theme.formActionSize
            Layout.preferredHeight: Ui.Theme.formActionSize
            iconSize: Ui.Theme.formActionIconSize
            enabled: !!pane.controller.suspendPolicyState.error || !!pane.controller.suspendPolicyState.last_error || !pane.controller.suspendPolicyState.available
            icon: pane.errorDetailsOpen ? "expand_less" : "info"
            accessibleName: qsTr("Automatic sleep diagnostic details")
            onClicked: pane.errorDetailsOpen = !pane.errorDetailsOpen
        }
        Ui.FlatIconButton {
            objectName: "suspendPolicyRetry"
            Layout.preferredWidth: Ui.Theme.formActionSize
            Layout.preferredHeight: Ui.Theme.formActionSize
            iconSize: Ui.Theme.formActionIconSize
            icon: "refresh"
            accessKey: "R"
            accessibleName: qsTr("Retry settings")
            enabled: pane.controller.suspendPolicyError.length > 0 && pane.controller.suspendPolicyDirty && (pane.controller.suspendPolicyCriticalOnly ? pane.criticalInteractive : pane.interactive)
            onClicked: pane.controller.saveSuspendPolicy()
        }
    }
    Ui.FieldLabel {
        objectName: "suspendPolicyDiagnostic"
        Layout.fillWidth: true
        visible: pane.errorDetailsOpen && (!!pane.controller.suspendPolicyState.error || !!pane.controller.suspendPolicyState.last_error || !pane.controller.suspendPolicyState.available)
        text: pane.controller.suspendPolicyState.error || pane.controller.suspendPolicyState.last_error || qsTr("Automatic suspend requires the managed hypridle integration.")
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
