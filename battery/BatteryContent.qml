pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ChooserSurface {
    id: content

    required property BatteryController controller
    readonly property var battery: controller.battery || ({})
    readonly property var protection: controller.protection
    readonly property var policy: controller.policy
    readonly property var device: controller.primaryDevice || ({})
    readonly property string policyError: protection.error || ""
    readonly property string errorMessage: controller.lastError.length > 0
        ? controller.lastError : (controller.refreshError.length > 0
            ? controller.refreshError : policyError)

    Ui.ChooserShortcuts {
        controller: content.controller
        navigationEnabled: true
        refreshEnabled: !content.controller.actionInFlight
        detailsTabEnabled: true
        onRefreshRequested: content.controller.refreshAll()
        onDetailsTabRequested: content.controller.cycleViewTab()
    }

    Connections {
        target: content.controller
        function onViewTabChanged(): void { detailPage.contentY = 0; }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Ui.Theme.contentMargin
        spacing: Ui.Theme.spacingMd

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.headerHeight
            spacing: Ui.Theme.spacingMd

            Ui.FlatIconButton {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignVCenter
                icon: "󰂂"
                iconSize: Ui.Theme.iconSizeLarge
                flatIconColor: Ui.Theme.accent
                enabled: !content.controller.screenshotInFlight
                    && !content.controller.actionInFlight
                    && !content.controller.settingsOperationActive
                accessibleName: "Copy Battery & Power panel screenshot"
                toolTip: content.controller.screenshotStatus.length > 0
                    ? content.controller.screenshotStatus
                    : "Battery & Power · click to copy a screenshot"
                onClicked: content.controller.screenshotRequested()
            }

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

        Ui.SegmentedControl {
            Layout.fillWidth: true
            Layout.preferredHeight: Ui.Theme.compactControlHeight
            options: [
                { value: "battery", label: "Battery" },
                { value: "power", label: "Power" }
            ]
            value: content.controller.viewTab
            interactive: !content.controller.actionInFlight
            onSelected: function (value) { content.controller.selectViewTab(value); }
        }

        Ui.DetailFlickable {
            id: detailPage
            Layout.fillWidth: true
            Layout.fillHeight: true

            BatteryOverviewPane {
                visible: content.controller.viewTab === "battery"
                controller: content.controller
                battery: content.battery
                device: content.device
                protection: content.protection
            }

            PowerControlsPane {
                visible: content.controller.viewTab === "power"
                controller: content.controller
            }
        }
    }
}
