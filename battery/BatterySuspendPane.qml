pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    objectName: "powerSuspendCard"
    verticalContentPadding: Ui.Theme.spacingMd
    height: contentImplicitHeight + 2 * verticalContentPadding

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingXs

        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Lock & suspend")
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
            toolTip: pane.controller.powerSuspend.keep_awake === undefined
                ? qsTr("Keep awake requires an updated bar-daemon")
                : (!pane.controller.backend.ready
                    ? qsTr("Reconnect to the power service to change Keep awake")
                    : (pane.controller.keepAwakeReleaseOnly
                        ? qsTr("Suspend status unavailable · turn off Keep awake")
                        : (pane.controller.keepAwake
                            ? qsTr("Turn off Keep awake · allow suspend and hibernate again")
                            : qsTr("Keep awake · block suspend, hibernate and lid suspend; locking and screen blanking continue"))))
            enabled: pane.controller.canSetKeepAwake
            onClicked: pane.controller.toggleKeepAwake()
        }

        Repeater {
            model: ["lock", "suspend", "hibernate"]

            delegate: Ui.ActionButton {
                required property string modelData
                objectName: "suspendAction-" + modelData
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                icon: modelData === "lock" ? "󰌾" : (modelData === "suspend" ? "󰖔" : "󰒲")
                iconSize: Ui.Theme.iconSizeLarge
                labelColor: modelData === "lock" ? Ui.Theme.accent : (modelData === "suspend" ? (Ui.Theme.dark ? "#a78bfa" : "#7c3aed") : Ui.Theme.warning)
                backgroundColor: Ui.Theme.input
                borderColor: "transparent"
                accessibleName: Presentation.suspendActionName(modelData)
                toolTip: accessibleName + " · " + Presentation.suspendCapabilityDescription(pane.controller.powerSuspend, modelData)
                enabled: pane.controller.canPowerSuspendAction(modelData)
                onClicked: pane.controller.powerSuspendAction(modelData)
            }
        }
    }

    RowLayout {
        objectName: "suspendStatusRow"
        Layout.fillWidth: true
        visible: pane.controller.suspendStatus.length > 0
        spacing: Ui.Theme.spacingSm

        Ui.FieldLabel {
            objectName: "suspendStatusText"
            Layout.fillWidth: true
            text: pane.controller.suspendStatus
            wrapMode: Text.Wrap
            elide: Text.ElideNone
            color: pane.controller.suspendBusy ? Ui.Theme.mutedText : (pane.controller.suspendError.length > 0 ? Ui.Theme.danger : Ui.Theme.warning)
        }

        Ui.FlatIconButton {
            objectName: "suspendRetryButton"
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            visible: pane.controller.suspendError.length > 0 && !pane.controller.suspendBusy && !pane.controller.suspendOutcomeUnknown
            icon: "󰑐"
            flatIconColor: Ui.Theme.accent
            accessibleName: qsTr("Retry %1").arg(Presentation.suspendActionName(pane.controller.suspendRetryAction))
            toolTip: accessibleName
            enabled: pane.controller.canPowerSuspendAction(pane.controller.suspendRetryAction)
            onClicked: pane.controller.powerSuspendAction(pane.controller.suspendRetryAction)
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
        objectName: "suspendFailureReason"
        Layout.fillWidth: true
        text: (pane.controller.powerSuspend.operation || {}).error || pane.controller.suspendError || pane.controller.powerSuspend.error || ""
        visible: text.length > 0 && pane.controller.suspendPendingAction.length === 0
        color: Ui.Theme.warning
        wrapMode: Text.Wrap
        elide: Text.ElideNone
    }
}
