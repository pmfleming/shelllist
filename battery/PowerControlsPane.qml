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
        height: contentImplicitHeight + 2 * verticalContentPadding

        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingMd

            Ui.ThemeText {
                Layout.fillWidth: true
                text: qsTr("Power mode")
                font.pixelSize: Ui.Theme.fontSizeHeading
                font.weight: Ui.Theme.fontWeightBold
            }

            BatteryProfileSelector {
                objectName: "batteryPowerModeProfile"
                Layout.preferredWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                accessibleName: qsTr("Power mode")
                options: pane.controller.profileOptions
                value: pane.controller.powerProfile.profile || ""
                interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                onSelected: function (value) {
                    pane.controller.setPowerProfile(value);
                }
            }
        }

        Ui.FieldLabel {
            Layout.fillWidth: true
            visible: !pane.controller.powerProfile.available
            text: qsTr("power-profiles-daemon is unavailable")
            color: Ui.Theme.warning
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

    }

    BatteryLevelsPane {
        controller: pane.controller
    }

    Ui.DetailColumnCard {
        objectName: "batteryHardwareTuningCard"
        verticalContentPadding: Ui.Theme.spacingMd
        headingSpacing: Ui.Theme.spacingMd
        height: contentImplicitHeight + headingHeight + headingSpacing + 2 * verticalContentPadding
        title: qsTr("Hardware power tuning")
        visible: (pane.controller.powerProfile.battery_aware !== null && pane.controller.powerProfile.battery_aware !== undefined) || (pane.controller.powerProfile.actions || []).length > 0

        Ui.ToggleRow {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            visible: pane.controller.powerProfile.battery_aware !== null && pane.controller.powerProfile.battery_aware !== undefined
            title: qsTr("Adaptive hardware tuning")
            subtitle: qsTr("Tune hardware for battery and charger state")
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
                subtitle: modelData.name === "trickle_charge" ? qsTr("Charging behaviour · not a charge limit") : (modelData.description || "Power-saving action")
                checked: !!modelData.enabled
                interactive: pane.controller.powerProfile.available && !pane.controller.actionInFlight
                onClicked: pane.controller.setPowerActionEnabled(modelData.name, !checked)
            }
        }
    }

    BatterySleepPolicyPane {
        controller: pane.controller
    }

    BatterySleepPane {
        controller: pane.controller
    }
}
