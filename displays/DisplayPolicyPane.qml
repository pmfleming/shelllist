pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane
    required property DisplayController controller
    objectName: "displayPolicyCard"
    title: qsTr("When docked")
    contentSpacing: Ui.Theme.spacingSm

    Ui.FormField {
        Layout.fillWidth: true
        label: qsTr("Laptop screen")
        icon: "monitor"
        supportingText: qsTr("Manual layout means screen enablement is controlled by the saved layout. Choose and save a docking preference to resume automatic control, even if it matches the previously saved preference. The laptop screen returns if no external display remains active.")
        accessibleName: qsTr("Laptop screen when an external display is available")
        Ui.DropDownList {
            objectName: "dockedLaptopBehavior"
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            options: (pane.controller.manualDisplayEnablement ? [{
                value: "manual",
                label: pane.controller.selectedOutput && pane.controller.selectedOutput.disabled ? qsTr("Manual layout · Laptop off") : qsTr("Manual layout · Laptop on"),
                enabled: false
            }] : []).concat([
                {
                    value: "keep-on",
                    label: qsTr("Keep laptop screen on")
                },
                {
                    value: "auto-off",
                    label: qsTr("Turn off automatically")
                }
            ])
            value: pane.controller.dockingMode
            placeholder: qsTr("Not reported")
            interactive: pane.controller.canSetPolicy
            Accessible.name: qsTr("Laptop screen when docked")
            Accessible.description: qsTr("Enter or Tab saves; Escape discards. The laptop screen returns if external displays disconnect.")
            onSelected: function (value) {
                if (value === "keep-on" || value === "auto-off")
                    pane.controller.setPreferExternal(value === "auto-off");
            }
        }
    }
    Ui.FeedbackSource {
        objectName: "dockingSaveStatus"
        text: pane.controller.pendingAction === "policy" ? qsTr("Saving preference…") : pane.controller.dirty || pane.controller.trial ? qsTr("Finish or discard layout changes before changing this preference.") : !pane.controller.dockingPreferenceKnown ? qsTr("Docking preference not reported") : pane.controller.manualDisplayEnablement ? qsTr("Manual layout controls the laptop screen. Choose a docking preference to resume automatic control.") : ""
        summaryText: pane.controller.pendingAction === "policy" ? qsTr("Saving preference…") : pane.controller.dirty || pane.controller.trial ? qsTr("Finish layout changes first") : !pane.controller.dockingPreferenceKnown ? qsTr("Docking preference not reported") : qsTr("Manual layout · Docking preference overridden")
    }
}
