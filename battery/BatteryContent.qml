pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.PanelSurface {
    id: content

    required property BatteryController controller
    chooserController: controller
    navigationContent: detailPage
    readonly property var battery: controller.battery || ({})
    readonly property var protection: controller.protection
    readonly property var device: controller.primaryDevice || ({})
    readonly property string policyError: protection.error || ""
    property string pendingReview: ""
    property string reviewDeviceId: ""

    function review(kind: string): void {
        detailsNavigation.finishEditor(false);
        reviewDeviceId = String(device.id || "");
        pendingReview = kind;
    }
    Binding {
        target: content.controller
        property: "navigationBlocked"
        value: content.pendingReview.length > 0
    }
    Connections {
        target: content.controller
        function onViewTabChanged(): void { content.pendingReview = ""; }
        function onUiActiveChanged(): void { content.pendingReview = ""; }
        function onSelectedDeviceChanged(): void {
            if (content.pendingReview === "calibration" && content.reviewDeviceId !== String(content.device.id || ""))
                content.pendingReview = "";
        }
    }
    onVisibleChanged: if (!visible) pendingReview = ""
    readonly property string errorMessage: controller.lastError.length > 0 ? controller.lastError : (controller.transportError.length > 0 ? controller.transportError : (controller.refreshError.length > 0 ? controller.refreshError : policyError))

    Shortcut {
        sequence: "F5"
        enabled: content.controller.uiActive && !content.controller.actionInFlight && !content.controller.navigationBlocked
        onActivated: content.controller.refreshAll()
    }
    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: content.controller.uiActive && !content.controller.navigationBlocked && !content.detailsNavigation.popupOpen
        onActivated: content.changeTab(false)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: content.controller.uiActive && !content.controller.navigationBlocked && !content.detailsNavigation.popupOpen
        onActivated: content.changeTab(true)
    }

    Ui.ConfirmationDialog {
        objectName: "batterySafetyReview"
        visible: content.pendingReview.length > 0
        title: content.pendingReview === "critical" ? qsTr("Enable critical-battery hibernation?") : qsTr("Calibrate battery?")
        detail: content.pendingReview === "critical" ? qsTr("Use only one automatic power manager and verify that hibernation works on this device. A warning period precedes hibernation; locking and inhibitors remain enforced.") : qsTr("Calibration may discharge and recharge the battery and take several hours. Keep the power supply connected. You can cancel calibration from Charging actions.")
        acceptLabel: content.pendingReview === "critical" ? qsTr("Enable") : qsTr("Calibrate")
        acceptTone: "accent"
        acceptEnabled: !content.controller.actionInFlight && (content.pendingReview === "critical" ? content.controller.backend.ready && !content.controller.suspendPolicySaving : content.reviewDeviceId === String(content.device.id || "") && content.controller.calibrationSupported && !!content.battery.plugged && !content.controller.calibrating && !content.controller.batteryOperationActive && !content.controller.thresholdOperationActive)
        onAccepted: {
            if (!acceptEnabled) return;
            const kind = content.pendingReview;
            content.pendingReview = "";
            if (kind === "critical") content.controller.updateSuspendPolicy("critical_battery", "enabled", true);
            else if (kind === "calibration") content.controller.toggleCalibration();
        }
        onCancelled: content.pendingReview = ""
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.headerHeight
            spacing: Ui.Theme.spacingMd

            Ui.ThemeText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                elide: Text.ElideRight
                text: qsTr("Battery & Power")
                font.pixelSize: Ui.Theme.fontSizeTitle
                font.weight: Ui.Theme.fontWeightBold
            }

            Ui.ThemeText {
                text: content.battery.available ? Math.round(Number(content.battery.percentage) || 0) + "%" : "Unavailable"
                color: content.battery.critical ? Ui.Theme.danger : (content.battery.warning ? Ui.Theme.warning : Ui.Theme.accent)
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

            Ui.ThemeText {
                id: errorText
                anchors.fill: parent
                anchors.margins: 10
                text: content.errorMessage
                color: Ui.Theme.danger
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }

        Ui.DetailFlickable {
            id: detailPage
            objectName: "batteryDetailPage"
            viewMemory: content.controller.viewMemory
            memoryTab: content.controller.viewTab
            Layout.fillWidth: true
            Layout.fillHeight: true

            BatterySummaryPane {
                objectName: "batteryOverviewPane"
                visible: content.controller.viewTab === "overview"
                controller: content.controller
                battery: content.battery
            }

            BatteryCarePane {
                objectName: "batteryCarePane"
                visible: content.controller.viewTab === "care"
                controller: content.controller
                battery: content.battery
                device: content.device
                protection: content.protection
                onCalibrationRequested: content.review("calibration")
            }

            PowerControlsPane {
                objectName: "batteryPowerPane"
                visible: content.controller.viewTab === "power"
                controller: content.controller
                onCriticalEnableRequested: content.review("critical")
            }
        }

        Ui.DetailsTabBar {
            objectName: "batteryViewTabs"
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.controlHeight
            tabs: content.controller.viewTabs
            selectedValue: content.controller.viewTab
            enabled: !content.controller.actionInFlight
            onSelected: function (value) {
                content.controller.selectViewTab(value);
            }
        }
    }
}
