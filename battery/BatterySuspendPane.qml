pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Ui.DetailColumnCard {
    id: pane

    required property BatteryController controller
    objectName: "powerSuspendCard"

    RowLayout {
        Layout.fillWidth: true
        spacing: Ui.Theme.spacingXs

        Ui.ThemeText {
            Layout.fillWidth: true
            text: qsTr("Lock & suspend")
            font.pixelSize: Ui.Theme.groupHeadingSize
            font.weight: Ui.Theme.groupHeadingWeight
            Layout.minimumWidth: 0
            wrapMode: Text.Wrap
        }

        Ui.ActionButton {
            objectName: "keepAwakeButton"
            accessKey: "K"
            Layout.preferredWidth: Ui.Theme.formActionSize
            Layout.preferredHeight: Ui.Theme.formActionSize
            icon: "coffee"
            iconColor: pane.controller.keepAwake ? labelColor : Ui.Theme.mix(Ui.Theme.text, Qt.color(Presentation.profileTint("performance")), 0.35)
            iconSize: Ui.Theme.formActionIconSize
            tone: pane.controller.keepAwake ? "accent" : "normal"
            accessibleName: qsTr("Keep awake")
            Accessible.role: Accessible.CheckBox
            Accessible.checkable: true
            Accessible.checked: pane.controller.keepAwake
            Accessible.onToggleAction: if (enabled)
                pane.controller.toggleKeepAwake()
            toolTip: pane.controller.powerSuspend.keep_awake === undefined ? qsTr("Keep awake requires an updated bar-daemon") : (!pane.controller.backend.ready ? qsTr("Reconnect to the power service to change Keep awake") : (pane.controller.keepAwakeReleaseOnly ? qsTr("Suspend status unavailable · turn off Keep awake") : (pane.controller.keepAwake ? qsTr("Turn off Keep awake · allow suspend and hibernate again") : qsTr("Keep awake · block suspend, hibernate and lid suspend; locking and screen blanking continue"))))
            enabled: pane.controller.canSetKeepAwake
            onClicked: pane.controller.toggleKeepAwake()
        }

        Ui.SurfaceActionRow {
            Layout.preferredWidth: 3 * Ui.Theme.formActionSize + 2 * Ui.Theme.spacingSm
            Layout.minimumWidth: 3 * Ui.Theme.minimumSecondaryActionHeight + 2 * Ui.Theme.minimumActionGap
            headerCommands: false
            compactSecondaryActions: true
            actionObjectNamePrefix: "suspendAction-"
            actions: ["lock", "suspend", "hibernate"].map(function (action) {
                return {id: action, accessKey: ({lock: "L", suspend: "U", hibernate: "H"})[action],
                    label: Presentation.suspendActionName(action),
                    icon: ({lock: "lock", suspend: "bedtime", hibernate: "snooze"})[action],
                    enabled: pane.controller.canPowerSuspendAction(action),
                    metadata: {toolTip: Presentation.suspendActionName(action) + " · " + Presentation.suspendCapabilityDescription(pane.controller.powerSuspend, action)},
                    presentation: {group: "toolbar", tone: "normal",
                        iconColor: Ui.Theme.mix(Ui.Theme.text, Qt.color(({lock: Presentation.profileTint("power-saver"), suspend: Presentation.profileTint("balanced"), hibernate: "#a39bb0"})[action]), 0.35)}};
            })
            onTriggered: function (action) { pane.controller.powerSuspendAction(action); }
        }
    }

    Ui.FeedbackSource {
        objectName: "suspendStatusText"
        text: pane.controller.suspendStatus
        summaryText: pane.controller.suspendBusy ? qsTr("Sleep action pending") : pane.controller.suspendOutcomeUnknown ? qsTr("Sleep outcome unknown") : qsTr("Sleep action needs attention")
        tone: pane.controller.suspendBusy ? "info" : pane.controller.suspendError.length ? "error" : "warning"
    }

    Ui.FeedbackSource {
        objectName: "keepAwakeStatus"
        active: pane.controller.keepAwakePending || pane.controller.keepAwakeError.length > 0
        text: pane.controller.keepAwakePending ? qsTr("Updating Keep awake…") : pane.controller.keepAwakeError
        summaryText: pane.controller.keepAwakePending ? qsTr("Updating Keep awake…") : qsTr("Keep awake change failed")
        tone: pane.controller.keepAwakeError.length ? "error" : "info"
    }

    Ui.FeedbackSource {
        objectName: "suspendFailureReason"
        text: (pane.controller.powerSuspend.operation || {}).error || pane.controller.suspendError || pane.controller.powerSuspend.error || ""
        active: pane.controller.suspendPendingAction.length === 0
        summaryText: qsTr("Sleep action failed")
        tone: "warning"
    }
}
