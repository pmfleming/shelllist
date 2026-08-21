pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui
import "BatteryPresentation.js" as Presentation

Ui.ChooserSurface {
    id: content

    required property BatteryController controller
    readonly property var battery: controller.battery || ({})
    readonly property var protection: controller.protection
    readonly property var policy: controller.policy
    readonly property var device: controller.primaryDevice || ({})
    readonly property string policyError: protection.error || ""
    readonly property string errorMessage: controller.lastError.length > 0
        ? controller.lastError : policyError

    Ui.ChooserShortcuts {
        controller: content.controller
        navigationEnabled: true
        refreshEnabled: !content.controller.actionInFlight
        onRefreshRequested: content.controller.backend.snapshot()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.headerHeight
            spacing: Ui.Theme.spacingMd

            Text {
                Layout.fillWidth: true
                text: "Battery & Power"
                color: Ui.Theme.text
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }

            Text {
                text: content.battery.available
                    ? Math.round(Number(content.battery.percentage) || 0) + "%" : "Unavailable"
                color: content.battery.critical ? Ui.Theme.danger
                    : (content.battery.warning ? Ui.Theme.warning : Ui.Theme.accent)
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeDisplay
                font.weight: Ui.Theme.fontWeightBold
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? errorText.implicitHeight + 20 : 0
            visible: content.errorMessage.length > 0
            radius: Ui.Theme.cardRadius
            color: Ui.Theme.dangerBackground
            border.color: Ui.Theme.withAlpha(Ui.Theme.danger, 0.45)

            Text {
                id: errorText
                anchors.fill: parent
                anchors.margins: 10
                text: content.errorMessage
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
                font.family: Ui.Theme.fontFamily
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Ui.DetailFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Ui.DetailCard {
                height: 190
                title: "Current status"
                entries: [
                    { label: "State", value: Presentation.stateLabel(content.battery),
                        valueColor: content.battery.plugged ? Ui.Theme.active : Ui.Theme.text,
                        valueBold: true },
                    { label: "Time", value: Presentation.timeLabel(content.battery) },
                    { label: "Power", value: Number(content.battery.power_watts || 0).toFixed(1) + " W" },
                    { label: "Health", value: content.battery.health_percent === null
                        || content.battery.health_percent === undefined ? "Unknown"
                        : content.battery.health_percent + "%" },
                    { label: "Cycles", value: content.battery.cycles === null
                        || content.battery.cycles === undefined ? "Unknown"
                        : String(content.battery.cycles) },
                    { label: "Charge", value: Math.round(Number(content.battery.percentage) || 0) + "%" }
                ]
            }

            Ui.DetailColumnCard {
                height: 250
                title: "Battery history · 7 days"

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: Presentation.historyRange(content.controller.batteryHistory)
                    color: Ui.Theme.mutedText
                }

                BatteryHistoryGraph {
                    points: content.controller.batteryHistory.points || []
                    metric: "percentage"
                    label: "Charge level"
                    valueText: Math.round(Number(content.battery.percentage) || 0) + "%"
                    lineColor: content.battery.warning ? Ui.Theme.warning : Ui.Theme.accent
                    minimumMaximum: 100
                }

                BatteryHistoryGraph {
                    points: content.controller.batteryHistory.points || []
                    metric: "time_to_full_seconds"
                    label: "Time until fully charged"
                    valueText: content.battery.charging
                        ? Presentation.duration(content.battery.time_to_full_seconds) : "Not charging"
                    lineColor: Ui.Theme.active
                    minimumMaximum: 3600
                    positiveOnly: true
                }
            }

            Ui.DetailColumnCard {
                height: 152 + Math.min(8,
                    (content.controller.energyOverview.applications || []).length) * 42
                title: "Application energy"

                Ui.SegmentedControl {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Ui.Theme.compactControlHeight
                    options: [
                        { value: "last-charge", label: "Since last charge" },
                        { value: "week", label: "Last 7 days" }
                    ]
                    value: content.controller.energyPeriod
                    onSelected: function (value) {
                        content.controller.selectEnergyPeriod(value);
                    }
                }

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: content.controller.energyLoading
                        ? "Updating estimated energy…"
                        : (content.controller.energyError.length > 0
                            ? content.controller.energyError
                            : Presentation.energy(
                                content.controller.energyOverview.total_energy_mwh)
                                + " attributed · "
                                + (content.controller.energyOverview.energy_confidence
                                    || "low") + " confidence")
                    color: content.controller.energyError.length > 0
                        ? Ui.Theme.warning : Ui.Theme.mutedText
                }

                Repeater {
                    model: (content.controller.energyOverview.applications || []).slice(0, 8)

                    delegate: Item {
                        id: energyRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38

                        RowLayout {
                            anchors.fill: parent
                            spacing: Ui.Theme.spacingSm

                            Item {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26

                                Image {
                                    id: appIcon
                                    anchors.fill: parent
                                    source: Quickshell.iconPath(
                                        energyRow.modelData.icon || "application-x-executable",
                                        "application-x-executable")
                                    sourceSize.width: width
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                }

                                Text {
                                    anchors.fill: parent
                                    visible: appIcon.status === Image.Error
                                    text: "󰀻"
                                    color: Ui.Theme.accent
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.family: Ui.Theme.iconFontFamily
                                    font.pixelSize: Ui.Theme.iconSizeSmall
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    text: energyRow.modelData.name
                                        || energyRow.modelData.target_id
                                    color: Ui.Theme.text
                                    elide: Text.ElideRight
                                    font.family: Ui.Theme.fontFamily
                                    font.pixelSize: Ui.Theme.fontSizeSmall
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 3
                                    radius: 2
                                    color: Ui.Theme.border

                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1,
                                            Number(energyRow.modelData.share) || 0))
                                        height: parent.height
                                        radius: parent.radius
                                        color: Ui.Theme.accent
                                    }
                                }
                            }

                            Text {
                                text: Presentation.energy(energyRow.modelData.energy_mwh)
                                color: Ui.Theme.accent
                                font.family: Ui.Theme.fontFamily
                                font.pixelSize: Ui.Theme.fontSizeCaption
                                font.weight: Ui.Theme.fontWeightDemiBold
                            }
                        }
                    }
                }

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    visible: !content.controller.energyLoading
                        && content.controller.energyError.length === 0
                        && (content.controller.energyOverview.applications || []).length === 0
                    text: "No attributable application energy in this period"
                    color: Ui.Theme.mutedText
                }
            }

            Ui.DetailColumnCard {
                height: 100
                visible: (content.battery.devices || []).length > 1
                title: "Battery device"

                Ui.SegmentedControl {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Ui.Theme.compactControlHeight
                    options: (content.battery.devices || []).map(function (batteryDevice) {
                        return { value: batteryDevice.id,
                            label: Presentation.deviceName(batteryDevice) };
                    })
                    value: content.device.id || ""
                    interactive: !content.controller.actionInFlight
                    onSelected: function (value) { content.controller.selectDevice(value); }
                }
            }

            Ui.DetailColumnCard {
                height: 150 + (content.controller.powerProfile.battery_aware === null
                    || content.controller.powerProfile.battery_aware === undefined ? 0 : 48)
                    + (content.controller.powerProfile.actions || []).length * 48
                    + (content.controller.powerProfile.active_holds || []).length * 34
                title: "Power mode"

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: content.controller.powerProfile.available
                        ? "Driver: " + (content.controller.powerProfile.driver || "unknown")
                            + (content.controller.powerProfile.version
                                ? " · power-profiles-daemon "
                                    + content.controller.powerProfile.version : "")
                        : "power-profiles-daemon is unavailable"
                    color: content.controller.powerProfile.available
                        ? Ui.Theme.mutedText : Ui.Theme.warning
                }

                Ui.SegmentedControl {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Ui.Theme.compactControlHeight
                    options: content.controller.profileOptions
                    value: content.controller.powerProfile.profile || ""
                    interactive: content.controller.powerProfile.available
                        && !content.controller.actionInFlight
                    onSelected: function (value) { content.controller.setPowerProfile(value); }
                }

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    visible: !!content.controller.powerProfile.performance_degraded
                    text: "Performance is limited: "
                        + content.controller.powerProfile.performance_degraded
                    color: Ui.Theme.warning
                }

                Repeater {
                    model: content.controller.powerProfile.active_holds || []

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
                    visible: content.controller.powerProfile.battery_aware !== null
                        && content.controller.powerProfile.battery_aware !== undefined
                    title: "Battery-aware profiles"
                    subtitle: "Let the daemon adapt profiles to battery state"
                    checked: !!content.controller.powerProfile.battery_aware
                    interactive: !content.controller.actionInFlight
                    onClicked: content.controller.setBatteryAware(!checked)
                }

                Repeater {
                    model: content.controller.powerProfile.actions || []

                    delegate: Ui.ToggleRow {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        title: Presentation.actionName(modelData.name)
                        subtitle: modelData.description || "Power-saving action"
                        checked: !!modelData.enabled
                        interactive: !content.controller.actionInFlight
                        onClicked: content.controller.setPowerActionEnabled(
                            modelData.name, !checked)
                    }
                }
            }

            Ui.DetailColumnCard {
                height: 145 + (content.controller.powerSleep.inhibitors || []).length * 30
                title: "Power & Sleep"

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: content.controller.powerSleep.available
                        ? (content.controller.powerSleep.preparing_for_sleep
                            ? "Preparing the session for sleep"
                            : "The session locks through logind before sleeping")
                        : "systemd-logind sleep controls are unavailable"
                    color: content.controller.powerSleep.available
                        ? Ui.Theme.mutedText : Ui.Theme.warning
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Ui.Theme.spacingSm

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: "Lock"
                        enabled: content.controller.powerSleep.available
                            && !content.controller.actionInFlight
                        onClicked: content.controller.powerSleepAction("lock")
                    }

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: "Suspend"
                        enabled: Presentation.sleepCapabilityAvailable(
                            content.controller.powerSleep.can_suspend)
                            && !content.controller.actionInFlight
                        onClicked: content.controller.powerSleepAction("suspend")
                    }

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: "Hibernate"
                        enabled: Presentation.sleepCapabilityAvailable(
                            content.controller.powerSleep.can_hibernate)
                            && !content.controller.actionInFlight
                        onClicked: content.controller.powerSleepAction("hibernate")
                    }
                }

                Repeater {
                    model: content.controller.powerSleep.inhibitors || []

                    delegate: Ui.FieldLabel {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        text: Presentation.inhibitorSummary(modelData)
                        color: modelData.mode === "block" ? Ui.Theme.warning : Ui.Theme.mutedText
                    }
                }
            }

            Ui.DetailColumnCard {
                height: 450
                title: "ThinkPad battery protection"

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    text: !content.controller.protectionSupported
                        ? "Charge thresholds are not exposed by this battery"
                        : (content.protection.managed
                            ? "Managed by bar-daemon · observed "
                                + Presentation.protectionRange(content.protection)
                            : "Observed " + Presentation.protectionRange(content.protection)
                                + " · not managed yet")
                    color: content.controller.protectionSupported
                        ? Ui.Theme.mutedText : Ui.Theme.warning
                }

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    visible: content.controller.protectionSupported
                        && content.protection.managed
                        && !content.protection.thresholds_verified
                    text: "The firmware accepted the range but reported a different value."
                    color: Ui.Theme.warning
                }

                Ui.ToggleRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    title: "Protect battery longevity"
                    subtitle: "Keep charging within the configured threshold range"
                    checked: !!content.protection.desired_enabled
                    interactive: content.controller.protectionSupported
                        && !content.controller.batteryOperationActive
                        && !content.controller.actionInFlight
                    onClicked: content.controller.setProtection(!checked)
                }

                Ui.LabeledValueSlider {
                    id: startThreshold
                    Layout.fillWidth: true
                    label: "Resume charging"
                    from: 0
                    to: 99
                    stepSize: 1
                    value: content.controller.draftStartPercent
                    valueText: Math.round(value) + "%"
                    enabled: content.controller.protectionSupported
                        && !content.controller.batteryOperationActive
                        && !content.controller.actionInFlight
                    onEdited: function (_dragging) {
                        content.controller.updateStartPercent(Math.round(value));
                    }
                }

                Ui.LabeledValueSlider {
                    id: endThreshold
                    Layout.fillWidth: true
                    label: "Stop charging"
                    from: 1
                    to: 100
                    stepSize: 1
                    value: content.controller.draftEndPercent
                    valueText: Math.round(value) + "%"
                    enabled: content.controller.protectionSupported
                        && !content.controller.batteryOperationActive
                        && !content.controller.actionInFlight
                    onEdited: function (_dragging) {
                        content.controller.updateEndPercent(Math.round(value));
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: !content.controller.thresholdDraftValid
                    text: "Resume charging must be lower than stop charging."
                    color: Ui.Theme.danger
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Ui.Theme.spacingSm

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: content.controller.thresholdDraftDirty
                            ? "Apply thresholds" : "Thresholds saved"
                        tone: content.controller.thresholdDraftDirty ? "accent" : "normal"
                        enabled: content.controller.thresholdDraftDirty
                            && content.controller.thresholdDraftValid
                            && content.controller.protectionSupported
                            && !content.controller.batteryOperationActive
                            && !content.controller.actionInFlight
                        onClicked: content.controller.applyThresholds()
                    }

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: content.protection.charge_once_active
                            ? "Charging to 100%" : "Charge to 100% once"
                        tone: content.protection.charge_once_active ? "active" : "normal"
                        enabled: content.battery.plugged
                            && !content.protection.charge_once_active
                            && !content.controller.batteryOperationActive
                            && content.controller.protectionSupported
                            && !content.controller.actionInFlight
                        onClicked: content.controller.chargeOnce()
                    }
                }

                Ui.FieldLabel {
                    Layout.fillWidth: true
                    visible: content.controller.calibrating
                    text: Presentation.calibrationLabel(content.controller.batteryOperation)
                    color: Ui.Theme.active
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Ui.Theme.spacingSm

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: content.controller.chargingInhibited
                            ? "Resume charging" : "Pause charging"
                        tone: content.controller.chargingInhibited ? "active" : "normal"
                        enabled: content.controller.inhibitionSupported
                            && (!content.controller.batteryOperationActive
                                || content.controller.chargingInhibited)
                            && !content.controller.actionInFlight
                        onClicked: content.controller.setChargingInhibited(
                            !content.controller.chargingInhibited)
                    }

                    Ui.ActionButton {
                        Layout.fillWidth: true
                        label: content.controller.calibrating
                            ? "Cancel calibration" : "Calibrate battery"
                        tone: content.controller.calibrating ? "active" : "normal"
                        enabled: content.controller.calibrationSupported
                            && content.battery.plugged
                            && (!content.controller.batteryOperationActive
                                || content.controller.calibrating)
                            && !content.controller.actionInFlight
                        onClicked: content.controller.toggleCalibration()
                    }
                }
            }

            Ui.DetailColumnCard {
                height: 335
                title: "Alerts"

                Ui.LabeledValueSlider {
                    Layout.fillWidth: true
                    label: "Low battery"
                    from: 0
                    to: 100
                    stepSize: 1
                    value: content.controller.draftWarningPercent
                    valueText: Math.round(value) + "%"
                    enabled: !content.controller.actionInFlight
                    onEdited: function (_dragging) {
                        content.controller.updateWarningPercent(Math.round(value));
                    }
                }

                Ui.LabeledValueSlider {
                    Layout.fillWidth: true
                    label: "Critical battery"
                    from: 0
                    to: 100
                    stepSize: 1
                    value: content.controller.draftCriticalPercent
                    valueText: Math.round(value) + "%"
                    enabled: !content.controller.actionInFlight
                    onEdited: function (_dragging) {
                        content.controller.updateCriticalPercent(Math.round(value));
                    }
                }

                Ui.ToggleRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    title: "Notify when full"
                    subtitle: "Show one notification when charging reaches 100%"
                    checked: content.controller.draftNotifyWhenFull
                    interactive: !content.controller.actionInFlight
                    onClicked: content.controller.updateNotifyWhenFull(!checked)
                }

                Ui.ToggleRow {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    title: "Automatic power saver"
                    subtitle: "Hold power saver below the low-battery level"
                    checked: content.controller.draftAutoPowerSaver
                    interactive: !content.controller.actionInFlight
                    onClicked: content.controller.updateAutoPowerSaver(!checked)
                }

                Text {
                    Layout.fillWidth: true
                    visible: !content.controller.alertDraftValid
                    text: "Critical percentage cannot exceed the low-battery percentage."
                    color: Ui.Theme.danger
                    font.family: Ui.Theme.fontFamily
                    font.pixelSize: Ui.Theme.fontSizeCaption
                }

                Ui.ActionButton {
                    Layout.fillWidth: true
                    label: content.controller.alertDraftDirty ? "Save alert policy" : "Alert policy saved"
                    tone: content.controller.alertDraftDirty ? "accent" : "normal"
                    enabled: content.controller.alertDraftDirty
                        && content.controller.alertDraftValid
                        && !content.controller.actionInFlight
                    onClicked: content.controller.applyAlertPolicy()
                }
            }

            Ui.DetailCard {
                height: 190
                title: Presentation.deviceName(content.device)
                entries: [
                    { label: "Kernel device", value: content.device.id || content.battery.native_path || "Unknown" },
                    { label: "Serial", value: content.device.serial || "Unavailable" },
                    { label: "Energy now", value: content.device.energy_now_wh === null
                        || content.device.energy_now_wh === undefined ? "Unknown"
                        : Number(content.device.energy_now_wh).toFixed(1) + " Wh" },
                    { label: "Full capacity", value: content.device.energy_full_wh === null
                        || content.device.energy_full_wh === undefined ? "Unknown"
                        : Number(content.device.energy_full_wh).toFixed(1) + " Wh" },
                    { label: "Design capacity", value: content.device.energy_full_design_wh === null
                        || content.device.energy_full_design_wh === undefined ? "Unknown"
                        : Number(content.device.energy_full_design_wh).toFixed(1) + " Wh" },
                    { label: "Desired range", value: Presentation.desiredRange(content.protection) }
                ]
            }
        }
    }
}
