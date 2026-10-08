pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Column {
    id: pane
    required property BatteryController controller
    signal criticalEnableRequested()
    width: parent.width
    spacing: Ui.Theme.spacingMd

    BatterySuspendPane {
        controller: pane.controller
    }
    BatterySuspendPolicyPane {
        controller: pane.controller
        onCriticalEnableRequested: pane.criticalEnableRequested()
    }

    Ui.DetailSection {
        objectName: "batteryAutomationSection"
        BatteryLevelsPane {
            Layout.fillWidth: true
            controller: pane.controller
        }
        Ui.DetailColumnCard {
            objectName: "batteryHardwareTuningCard"
            Layout.fillWidth: true
            title: qsTr("Hardware power tuning")
            visible: (pane.controller.powerProfile.battery_aware !== null && pane.controller.powerProfile.battery_aware !== undefined) || (pane.controller.powerProfile.actions || []).length > 0
            Ui.ToggleRow {
                Layout.fillWidth: true
                visible: pane.controller.powerProfile.battery_aware !== null && pane.controller.powerProfile.battery_aware !== undefined
                title: qsTr("Adaptive hardware tuning")
                compact: true
                icons: ["tune"]
                checked: !!pane.controller.powerProfile.battery_aware
                interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                onClicked: pane.controller.setBatteryAware(!checked)
            }
            Repeater {
                model: pane.controller.powerProfile.actions || []
                delegate: Ui.ToggleRow {
                    required property var modelData
                    Layout.fillWidth: true
                    title: Presentation.actionName(modelData.name)
                    subtitle: modelData.name === "trickle_charge" ? qsTr("Charging behaviour · not a charge limit") : (modelData.description || "")
                    checked: !!modelData.enabled
                    interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                    onClicked: pane.controller.setPowerActionEnabled(modelData.name, !checked)
                }
            }
        }
    }
}
