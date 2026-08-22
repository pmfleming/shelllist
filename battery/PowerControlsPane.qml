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
        height: 150 + (pane.controller.powerProfile.battery_aware === null
            || pane.controller.powerProfile.battery_aware === undefined ? 0 : 48)
            + (pane.controller.powerProfile.actions || []).length * 48
            + (pane.controller.powerProfile.active_holds || []).length * 34
        title: "Power mode"

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.powerProfile.available
                ? "Driver: " + (pane.controller.powerProfile.driver || "unknown")
                    + (pane.controller.powerProfile.version
                        ? " · power-profiles-daemon "
                            + pane.controller.powerProfile.version : "")
                : "power-profiles-daemon is unavailable"
            color: pane.controller.powerProfile.available
                ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        Ui.SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: pane.controller.profileOptions
            value: pane.controller.powerProfile.profile || ""
            interactive: pane.controller.powerProfile.available
                && !pane.controller.actionInFlight
            onSelected: function (value) { pane.controller.setPowerProfile(value); }
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: !!pane.controller.powerProfile.performance_degraded
            text: "Performance is limited: "
                + pane.controller.powerProfile.performance_degraded
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
            visible: pane.controller.powerProfile.battery_aware !== null
                && pane.controller.powerProfile.battery_aware !== undefined
            title: "Battery-aware profiles"
            subtitle: "Let the daemon adapt profiles to battery state"
            checked: !!pane.controller.powerProfile.battery_aware
            interactive: !pane.controller.actionInFlight
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
                interactive: !pane.controller.actionInFlight
                onClicked: pane.controller.setPowerActionEnabled(
                    modelData.name, !checked)
            }
        }
    }

    Ui.DetailColumnCard {
        height: 145 + (pane.controller.powerSleep.inhibitors || []).length * 30
        title: "Power & Sleep"

        Ui.FieldLabel {
            Layout.fillWidth: true
            text: pane.controller.powerSleep.available
                ? (pane.controller.powerSleep.preparing_for_sleep
                    ? "Preparing the session for sleep"
                    : "The session locks through logind before sleeping")
                : "systemd-logind sleep controls are unavailable"
            color: pane.controller.powerSleep.available
                ? Ui.Theme.mutedText : Ui.Theme.warning
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Lock"
                enabled: pane.controller.powerSleep.available
                    && !pane.controller.actionInFlight
                onClicked: pane.controller.powerSleepAction("lock")
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Suspend"
                enabled: Presentation.sleepCapabilityAvailable(
                    pane.controller.powerSleep.can_suspend)
                    && !pane.controller.actionInFlight
                onClicked: pane.controller.powerSleepAction("suspend")
            }

            Ui.ActionButton {
                Layout.fillWidth: true
                label: "Hibernate"
                enabled: Presentation.sleepCapabilityAvailable(
                    pane.controller.powerSleep.can_hibernate)
                    && !pane.controller.actionInFlight
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
