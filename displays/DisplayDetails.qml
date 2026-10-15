pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane
    required property DisplayController controller
    objectName: "displayDetails"
    chooserController: controller
    contentAvailable: true
    icon: controller.globalSettingsOpen ? "󰒓" : controller.selectedResult ? controller.selectedResult.icon : "󰍹"
    iconColor: controller.globalSettingsOpen ? Ui.Theme.accent : controller.selectedOutput && !controller.selectedOutput.disabled ? Ui.Theme.active : Ui.Theme.mutedText
    title: controller.globalSettingsOpen ? qsTr("Display settings") : controller.selectedResult ? controller.selectedResult.title : qsTr("Displays")
    subtitle: controller.globalSettingsOpen ? qsTr("Focus · all monitors") : controller.selectedResult ? controller.selectedResult.subtitle : ""
    actions: controller.globalSettingsOpen ? [] : controller.detailActions
    subtitleWeight: Ui.Theme.fontWeightMedium
    enabled: !controller.trial && !controller.discardPrompt && !controller.actionInFlight

    Ui.FeedbackSource {
        text: pane.controller.statusMessage || (!pane.controller.globalSettingsOpen && pane.controller.dirty ? qsTr("Unsaved layout · Preview changes") : "")
        summaryText: pane.controller.stale ? qsTr("Layout changed · Reload required") : pane.controller.dirty ? qsTr("Layout draft · Not applied") : qsTr("Display update needs attention")
        tone: pane.controller.statusMessage ? "warning" : "info"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: pane.sectionSpacing
        ColumnLayout {
            Layout.fillWidth: true
            // Empty arrangement controls must not consume the settings viewport.
            Layout.fillHeight: false
            spacing: Ui.Theme.spacingXs
            visible: !pane.controller.globalSettingsOpen && !!pane.controller.selectedOutput && pane.controller.detailsTab === "settings"
            DisplayCanvas {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(96, Math.min(180, pane.height * 0.23))
                controller: pane.controller
            }
            DisplayArrangementControls {
                Layout.fillWidth: true
                // Honor zero implicit height instead of reusing the last arranged height.
                Layout.preferredHeight: implicitHeight
                controller: pane.controller
            }
        }
        RowLayout {
            visible: pane.controller.globalSettingsOpen
            Layout.fillWidth: true
            Layout.minimumHeight: Ui.Theme.controlHeight
            Layout.preferredHeight: Ui.Theme.controlHeight
            Layout.maximumHeight: Ui.Theme.controlHeight
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                objectName: "backToDisplayList"
                visible: pane.controller.globalSettingsOpen
                accessKey: "B"
                Layout.preferredWidth: Ui.Theme.controlHeight
                Layout.preferredHeight: Ui.Theme.controlHeight
                icon: "󰅁"
                accessibleName: pane.controller.globalSettingsOpen && pane.controller.detailsTab !== "focus" ? qsTr("Back to focus settings") : qsTr("Back to displays")
                toolTip: accessibleName
                onClicked: pane.controller.closeDetails()
            }
            Item { Layout.fillWidth: true }
        }
        Ui.CenteredMessage {
            objectName: "displayEmptyDetails"
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !pane.controller.globalSettingsOpen && !pane.controller.selectedOutput
            text: qsTr("No display selected · go back to the list or clear search")
        }
        DisplayFocusPane {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: pane.controller.globalSettingsOpen
            controller: pane.controller
        }
        Ui.TabbedDetailsStack {
            objectName: "displayDetailsTabs"
            visible: !pane.controller.globalSettingsOpen && !!pane.controller.selectedOutput
            Layout.fillWidth: true
            Layout.fillHeight: true
            footerHeight: pane.controlHeight
            sectionSpacing: pane.sectionSpacing
            selectedValue: pane.controller.detailsTab
            tabs: [
                {
                    value: "settings",
                    label: qsTr("Settings"),
                    icon: "󰒓"
                },
                {
                    value: "information",
                    label: qsTr("Information"),
                    icon: "󰋼"
                }
            ]
            onSelected: function (value) {
                pane.controller.detailsTab = value;
            }

            DisplayLayoutPane {
                anchors.fill: parent
                visible: pane.controller.detailsTab === "settings"
                controller: pane.controller
            }
            DisplayInformation {
                anchors.fill: parent
                visible: pane.controller.detailsTab === "information"
                controller: pane.controller
            }
        }
    }
}
