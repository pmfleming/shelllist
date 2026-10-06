pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane
    required property DisplayController controller
    objectName: "displayDetails"
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    chooserController: controller
    contentAvailable: true
    controlHeight: actionHeight
    icon: controller.globalSettingsOpen ? "󰒓" : controller.selectedResult ? controller.selectedResult.icon : "󰍹"
    iconColor: controller.globalSettingsOpen ? Ui.Theme.accent : controller.selectedOutput && !controller.selectedOutput.disabled ? Ui.Theme.active : Ui.Theme.mutedText
    title: controller.globalSettingsOpen ? qsTr("Display settings") : controller.selectedResult ? controller.selectedResult.title : qsTr("Displays")
    subtitle: controller.globalSettingsOpen ? qsTr("Focus · all monitors") : controller.selectedResult ? controller.selectedResult.subtitle : ""
    actions: controller.globalSettingsOpen ? [] : controller.detailActions
    subtitleWeight: Ui.Theme.fontWeightMedium
    enabled: !controller.trial && !controller.discardPrompt && !controller.actionInFlight

    ColumnLayout {
        anchors.fill: parent
        spacing: pane.sectionSpacing
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingXs
            visible: !pane.controller.globalSettingsOpen && !!pane.controller.selectedOutput
            DisplayCanvas {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(96, Math.min(180, pane.height * 0.23))
                controller: pane.controller
            }
            DisplayArrangementControls {
                Layout.fillWidth: true
                controller: pane.controller
            }
            Ui.ThemeText {
                objectName: "displayLayoutPreviewLabel"
                Layout.fillWidth: true
                text: pane.controller.stale ? qsTr("Layout changed · reload") : pane.controller.dirty ? qsTr("Preview layout · not applied") : qsTr("Drag to an edge or choose a direction")
                color: pane.controller.stale ? Ui.Theme.warning : Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
                wrapMode: Text.Wrap
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: pane.controller.globalSettingsOpen || !!pane.controller.statusMessage || pane.controller.dirty || pane.controller.stale
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
            Ui.ThemeText {
                Layout.fillWidth: true
                text: pane.controller.statusMessage || (!pane.controller.globalSettingsOpen && pane.controller.dirty ? qsTr("Unsaved layout · Preview changes") : "")
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeSmall
                color: pane.controller.statusMessage ? Ui.Theme.warning : Ui.Theme.mutedText
            }
            Ui.FlatIconButton {
                objectName: "reloadDisplayLayout"
                accessKey: "X"
                visible: !pane.controller.globalSettingsOpen
                Layout.preferredWidth: Ui.Theme.controlHeight
                Layout.preferredHeight: Ui.Theme.controlHeight
                icon: "󰕍"
                accessibleName: pane.controller.stale ? qsTr("Reload current displays") : qsTr("Discard layout changes")
                toolTip: accessibleName
                enabled: pane.controller.canChange && (pane.controller.dirty || pane.controller.stale)
                onClicked: pane.controller.reloadDraft()
            }
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
