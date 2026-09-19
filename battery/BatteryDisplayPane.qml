pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.DetailColumnCard {
    id: pane
    required property BatteryController controller
    objectName: "displayPolicyCard"
    title: qsTr("Laptop & external display")
    verticalContentPadding: Ui.Theme.spacingMd
    headingSpacing: Ui.Theme.spacingMd
    height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding

    Ui.ToggleRow {
        objectName: "preferExternalDisplay"
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        title: qsTr("Use only the external display")
        subtitle: qsTr("Keep the laptop screen as a fallback while docking")
        checked: !!(pane.controller.displayPolicyState.policy || {}).prefer_external
        interactive: pane.controller.displayPolicyState.available && pane.controller.backend.ready && !pane.controller.actionInFlight && !pane.controller.displayPolicySaving
        onClicked: pane.controller.setPreferExternal(!checked)
    }

    Ui.FieldLabel {
        objectName: "displayPolicyStatus"
        Layout.fillWidth: true
        text: pane.controller.displayPolicyError || pane.controller.displayPolicyState.error ||
            (!pane.controller.displayPolicyState.available ? qsTr("Requires daemon display integration (programs.shelllist.displays.enable).") :
            (pane.controller.displayPolicySaving ? qsTr("Saving display preference…") :
            ({ "settling": qsTr("Waiting for the external display to stay stable before hiding the laptop screen."),
               "external": qsTr("External-only mode · laptop fallback returns if the display disconnects."),
               "internal": qsTr("Using the laptop screen · no usable external display detected."),
               "all-displays": qsTr("Laptop screen enabled alongside connected external displays."),
               "sleeping": qsTr("Display changes paused while preparing for sleep."),
               "pending": qsTr("Applying display preference…") })[pane.controller.displayPolicyState.status] || qsTr("Checking displays…")))
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        color: pane.controller.displayPolicyError || pane.controller.displayPolicyState.error ? Ui.Theme.warning : Ui.Theme.mutedText
    }
}
