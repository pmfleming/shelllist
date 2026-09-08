pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Column {
    id: pane

    required property BatteryController controller

    width: parent.width
    spacing: Ui.Theme.verticalSpacing(Ui.Theme.spacingMd, Ui.Theme.densityScale(height, 0))

    Ui.DetailColumnCard {
        objectName: "powerModeCard"
        verticalContentPadding: Ui.Theme.spacingMd
        headingSpacing: Ui.Theme.spacingMd
        height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
        title: qsTr("Power mode")

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.powerProfile.available ? "Driver: " + (pane.controller.powerProfile.driver || "unknown") + (pane.controller.powerProfile.version ? " · power-profiles-daemon " + pane.controller.powerProfile.version : "") : "power-profiles-daemon is unavailable"
            color: pane.controller.powerProfile.available ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        Ui.SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: pane.controller.profileOptions
            value: pane.controller.powerProfile.profile || ""
            interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
            onSelected: function (value) {
                pane.controller.setPowerProfile(value);
            }
        }

        Ui.ToggleRow {
            objectName: "automaticPowerSaverToggle"
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            title: qsTr("Automatic power saver")
            subtitle: "Hold power saver below " + pane.controller.draftWarningPercent + "% · threshold in Battery care"
            checked: pane.controller.draftAutoPowerSaver
            interactive: !pane.controller.actionInFlight
            onClicked: pane.controller.updateAutoPowerSaver(!checked)
        }

        Ui.SaveStatusLabel {
            Layout.fillWidth: true
            text: pane.controller.alertSaveStatus
            valid: pane.controller.alertDraftValid
            error: pane.controller.alertSaveError
            saving: pane.controller.alertOperationActive
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: !!pane.controller.powerProfile.performance_degraded
            text: "Performance is limited: " + pane.controller.powerProfile.performance_degraded
            color: Ui.Theme.warning
        }

        Repeater {
            model: pane.controller.powerProfile.active_holds || []

            delegate: Ui.FieldLabel {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                text: Presentation.holdSummary(modelData)
                color: Ui.Theme.active
            }
        }

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            visible: pane.controller.powerProfile.battery_aware !== null && pane.controller.powerProfile.battery_aware !== undefined
            title: qsTr("Battery-aware profiles")
            subtitle: "Let the daemon adapt profiles to battery state"
            checked: !!pane.controller.powerProfile.battery_aware
            interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
            onClicked: pane.controller.setBatteryAware(!checked)
        }

        Repeater {
            model: pane.controller.powerProfile.actions || []

            delegate: Ui.ToggleRow {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                title: Presentation.actionName(modelData.name)
                subtitle: modelData.description || "Power-saving action"
                checked: !!modelData.enabled
                interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                onClicked: pane.controller.setPowerActionEnabled(modelData.name, !checked)
            }
        }
    }

    Ui.DetailColumnCard {
        objectName: "powerSleepCard"
        height: 145 + (pane.controller.powerSleep.inhibitors || []).length * 30
        title: qsTr("Lock & sleep")

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.powerSleep.available ? (pane.controller.powerSleep.preparing_for_sleep ? "Preparing the session for sleep" : "Requests a session lock through logind before sleeping") : "systemd-logind sleep controls are unavailable"
            color: pane.controller.powerSleep.available ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Lock"
                enabled: pane.controller.powerSleep.available && !pane.controller.actionInFlight
                onClicked: pane.controller.powerSleepAction("lock")
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Suspend"
                enabled: pane.controller.powerSleep.available && Presentation.sleepCapabilityAvailable(pane.controller.powerSleep.can_suspend) && !pane.controller.powerSleep.preparing_for_sleep && !pane.controller.actionInFlight
                onClicked: pane.controller.powerSleepAction("suspend")
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Hibernate"
                enabled: pane.controller.powerSleep.available && Presentation.sleepCapabilityAvailable(pane.controller.powerSleep.can_hibernate) && !pane.controller.powerSleep.preparing_for_sleep && !pane.controller.actionInFlight
                onClicked: pane.controller.powerSleepAction("hibernate")
            }
        }

        Repeater {
            model: pane.controller.powerSleep.inhibitors || []

            delegate: Ui.FieldLabel {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                text: Presentation.inhibitorSummary(modelData)
                color: modelData.mode === "block" ? Ui.Theme.warning : Ui.Theme.mutedText
            }
        }
    }
}
