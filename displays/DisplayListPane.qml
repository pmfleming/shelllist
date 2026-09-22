pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane
    required property DisplayController controller
    objectName: "displayList"
    chooserController: controller
    resultModel: controller.filteredResultsModel
    filterText: controller.filterText
    placeholder: qsTr("Search displays…")
    emptyText: !controller.stateReady ? qsTr("Connecting…") : controller.outputs.length === 0 ? qsTr("No connected displays") : qsTr("No matching displays")
    icon: "󰍹"
    powered: controller.activeCount > 0
    powerVisible: false
    busy: controller.actionInFlight
    enabled: !controller.navigationBlocked
    refreshEnabled: !controller.actionInFlight && !controller.trial
    focusOnCompleted: controller.uiActive
    status: controller.statusMessage || qsTr("%1 active · %2 connected").arg(controller.activeCount).arg(controller.outputs.length)
    iconActionEnabled: controller.activeCount > 0
    iconAccessibleName: qsTr("Identify all enabled displays")
    onIconClicked: controller.identify()
    searchActionIcon: "󰒓"
    searchActionToolTip: qsTr("Display-wide settings")
    onSearchActionRequested: controller.displaySettingsOpen = !controller.displaySettingsOpen
    listOptionsComponent: controller.displaySettingsOpen ? settings : null

    Component {
        id: settings
        ColumnLayout {
            spacing: Ui.Theme.spacingSm
            Ui.SectionLabel { text: qsTr("Display-wide settings") }
            DisplayPolicyPane {
                Layout.fillWidth: true
                visible: pane.controller.hasInternal
                controller: pane.controller
            }
            Ui.ThemeText {
                Layout.fillWidth: true
                text: pane.controller.hasInternal ? qsTr("Saved docking preference. The laptop returns when external displays disconnect.") : qsTr("No docking preference on desktop-only setups.")
                wrapMode: Text.Wrap
                color: Ui.Theme.mutedText
                font.pixelSize: Ui.Theme.fontSizeSmall
            }
        }
    }
    rowDelegate: Component {
        DisplayListRow { listPane: pane }
    }
}
