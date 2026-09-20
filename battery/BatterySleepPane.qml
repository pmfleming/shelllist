pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    objectName: "powerSleepCard"
    verticalContentPadding: Ui.Theme.spacingMd
    height: contentImplicitHeight + 2 * verticalContentPadding

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingXs

        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Lock & sleep")
            font.pixelSize: Ui.Theme.fontSizeHeading
            font.weight: Ui.Theme.fontWeightBold
        }

        Ui.ActionButton {
            objectName: "keepAwakeButton"
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            icon: "󰅶"
            iconSize: Ui.Theme.iconSizeLarge
            tone: pane.controller.keepAwake ? "accent" : "normal"
            accessibleName: qsTr("Keep awake")
            Accessible.role: Accessible.CheckBox
            Accessible.checkable: true
            Accessible.checked: pane.controller.keepAwake
            Accessible.onToggleAction: if (enabled) pane.controller.toggleKeepAwake()
            toolTip: pane.controller.powerSleep.keep_awake === undefined
                ? qsTr("Keep awake requires an updated bar-daemon")
                : (!pane.controller.backend.ready
                    ? qsTr("Reconnect to the power service to change Keep awake")
                    : (pane.controller.keepAwakeReleaseOnly
                        ? qsTr("Sleep status unavailable · turn off Keep awake")
                        : (pane.controller.keepAwake
                            ? qsTr("Turn off Keep awake · allow sleep and hibernate again")
                            : qsTr("Keep awake · block sleep, hibernate and lid sleep; locking and screen blanking continue"))))
            enabled: pane.controller.canSetKeepAwake
            onClicked: pane.controller.toggleKeepAwake()
        }

        Repeater {
            model: ["lock", "suspend", "hibernate"]

            delegate: Ui.ActionButton {
                required property string modelData
                objectName: "sleepAction-" + modelData
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon: modelData === "lock" ? "󰌾" : (modelData === "suspend" ? "󰖔" : "󰒲")
                iconSize: Ui.Theme.iconSizeLarge
                labelColor: modelData === "lock" ? Ui.Theme.accent : (modelData === "suspend" ? (Ui.Theme.dark ? "#a78bfa" : "#7c3aed") : Ui.Theme.warning)
                backgroundColor: Ui.Theme.input
                borderColor: "transparent"
                accessibleName: Presentation.sleepActionName(modelData)
                toolTip: accessibleName + " · " + Presentation.sleepCapabilityDescription(pane.controller.powerSleep, modelData)
                enabled: pane.controller.canPowerSleepAction(modelData)
                onClicked: pane.controller.powerSleepAction(modelData)
            }
        }
    }

    RowLayout {
        objectName: "sleepStatusRow"
        Layout.fillWidth: true
        visible: pane.controller.sleepStatus.length > 0
        spacing: Ui.Theme.spacingSm

        Ui.FieldLabel {
            objectName: "sleepStatusText"
            Layout.fillWidth: true
            text: pane.controller.sleepStatus
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            color: pane.controller.sleepBusy ? Ui.Theme.mutedText : (pane.controller.sleepError.length > 0 ? Ui.Theme.danger : Ui.Theme.warning)
        }

        Ui.FlatIconButton {
            objectName: "sleepRetryButton"
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            visible: pane.controller.sleepError.length > 0 && !pane.controller.sleepBusy && !pane.controller.sleepOutcomeUnknown
            icon: "󰑐"
            flatIconColor: Ui.Theme.accent
            accessibleName: qsTr("Retry %1").arg(Presentation.sleepActionName(pane.controller.sleepRetryAction))
            toolTip: accessibleName
            enabled: pane.controller.canPowerSleepAction(pane.controller.sleepRetryAction)
            onClicked: pane.controller.powerSleepAction(pane.controller.sleepRetryAction)
        }
    }

    Ui.FieldLabel {
        objectName: "keepAwakeStatus"
        Layout.fillWidth: true
        visible: pane.controller.keepAwakePending || pane.controller.keepAwakeError.length > 0
        text: pane.controller.keepAwakePending ? qsTr("Updating Keep awake…") : pane.controller.keepAwakeError
        color: pane.controller.keepAwakeError.length > 0 ? Ui.Theme.danger : Ui.Theme.mutedText
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }

    Ui.FieldLabel {
        objectName: "sleepFailureReason"
        Layout.fillWidth: true
        text: (pane.controller.powerSleep.operation || {}).error || pane.controller.sleepError || pane.controller.powerSleep.error || ""
        visible: text.length > 0 && pane.controller.sleepPendingAction.length === 0
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
