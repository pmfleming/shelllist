pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ActionDetailsPane {
    id: pane
    required property DisplayController controller
    objectName: "displayDetails"
    readonly property int actionHeight: Math.max(36, Math.round(Ui.Theme.controlHeight * uiScale))
    readonly property bool narrowDetails: width - leftMargin - rightMargin < 440
    chooserController: controller
    contentAvailable: true
    headerHeight: Math.max(56, Math.round(64 * uiScale))
    controlHeight: actionHeight
    icon: controller.selectedResult ? controller.selectedResult.icon : "󰍹"
    iconColor: controller.selectedOutput && !controller.selectedOutput.disabled ? Ui.Theme.active : Ui.Theme.mutedText
    title: controller.selectedResult ? controller.selectedResult.title : qsTr("Displays")
    subtitle: controller.selectedResult ? controller.selectedResult.subtitle : ""
    actions: controller.detailActions
    subtitleWeight: Ui.Theme.fontWeightMedium
    stackedPrimary: narrowDetails
    enabled: !controller.trial && !controller.discardPrompt && !controller.actionInFlight
    onActionTriggered: function (actionId) {
        controller.triggerDetailAction(actionId);
    }
    Keys.onLeftPressed: function (event) {
        if (event.modifiers !== Qt.NoModifier)
            return;
        controller.closeDetails();
        event.accepted = true;
    }
    function focusNarrowDetails(): void {
        if (narrowDetails && controller.uiActive && !controller.arrangementOpen)
            backButton.forceActiveFocus();
    }
    Component.onCompleted: Qt.callLater(focusNarrowDetails)

    ColumnLayout {
        anchors.fill: parent
        spacing: pane.sectionSpacing
        RowLayout {
            Layout.fillWidth: true
            spacing: Ui.Theme.spacingSm
            Ui.FlatIconButton {
                id: backButton
                objectName: "backToDisplayList"
                Layout.preferredWidth: Ui.Theme.controlHeight
                Layout.preferredHeight: Ui.Theme.controlHeight
                icon: "󰅁"
                accessibleName: qsTr("Back to displays")
                toolTip: accessibleName
                onClicked: pane.controller.closeDetails()
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: pane.controller.statusMessage || (pane.controller.dirty ? qsTr("Unsaved · Preview changes affects the whole layout") : qsTr("Layout changes are drafted · Preview the whole layout before keeping"))
                wrapMode: Text.Wrap
                font.pixelSize: Ui.Theme.fontSizeSmall
                color: pane.controller.statusMessage ? Ui.Theme.warning : Ui.Theme.mutedText
            }
            Ui.FlatIconButton {
                objectName: "reloadDisplayLayout"
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
            visible: !pane.controller.selectedOutput
            text: qsTr("No display selected · go back to the list or clear search")
        }
        Ui.TabbedDetailsStack {
            objectName: "displayDetailsTabs"
            visible: !!pane.controller.selectedOutput
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
