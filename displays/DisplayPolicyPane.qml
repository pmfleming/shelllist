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

    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("When an external display is available")
        wrapMode: Text.Wrap
    }
    Ui.DropDownList {
        id: preference
        objectName: "dockedLaptopBehavior"
        Layout.fillWidth: true
        Layout.minimumWidth: 0
        options: [
            { value: "keep-on", label: qsTr("Keep laptop screen on") },
            { value: "auto-off", label: qsTr("Turn off automatically") }
        ]
        value: (pane.controller.displayPolicyState.policy || {}).prefer_external ? "auto-off" : "keep-on"
        interactive: pane.controller.canSetPolicy
        Accessible.name: qsTr("Laptop screen when docked")
        Accessible.description: qsTr("Saved automatically. The laptop screen returns if external displays disconnect.")
        onSelected: function (value) {
            pane.controller.setPreferExternal(value === "auto-off");
            // ComboBox changes its index on activation; show the acknowledged
            // preference until the daemon confirms the save, including failures.
            currentIndex = Qt.binding(function () { return preference.optionIndex(preference.value); });
        }
    }
    Ui.ThemeText {
        Layout.fillWidth: true
        text: qsTr("The laptop screen returns automatically if external displays disconnect.")
        wrapMode: Text.Wrap
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeSmall
    }
    Ui.ThemeText {
        objectName: "dockingSaveStatus"
        Layout.fillWidth: true
        text: pane.controller.pendingAction === "policy" ? qsTr("Saving preference…")
            : pane.controller.dirty || pane.controller.trial ? qsTr("Finish or discard layout changes before changing this preference.")
            : qsTr("Saved automatically · no preview needed")
        wrapMode: Text.Wrap
        color: Ui.Theme.mutedText
        font.pixelSize: Ui.Theme.fontSizeCaption
    }
}
