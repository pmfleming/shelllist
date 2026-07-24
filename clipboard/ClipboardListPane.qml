pragma ComponentBehavior: Bound

import QtQuick
import Shelllist.Ui as Ui

Ui.ChooserListPane {
    id: pane

    required property ClipboardController controller
    required property real uiScale
    chooserController: controller
    densityScale: uiScale
    resultModel: controller.filteredResultsModel
    emptyText: controller.refreshInFlight ? "Loading clipboard history…" : "Clipboard history is empty"
    placeholder: "Search clipboard…"
    icon: "󰅇"
    powered: true
    refreshing: controller.refreshInFlight
    busy: controller.refreshInFlight
    powerEnabled: false
    refreshEnabled: !controller.refreshInFlight
    iconActionEnabled: !controller.screenshotInFlight && !controller.actionInFlight
    filterText: controller.filterText
    status: controller.status
    bodySpacing: Math.round(Ui.Theme.spacingMd * uiScale)
    toolbarHeight: Math.round(Ui.Theme.controlHeight * uiScale)
    onIconClicked: controller.screenshotRequested()

    rowDelegate: Component {
        ClipboardListRow { listPane: pane }
    }

    toolbarComponent: Component {
        Ui.ActionToolbar {
            actions: [{
                id: "pause", label: pane.controller.settings.capture_paused ? "Resume" : "Pause", icon: "󰏤", shortcut: "",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: pane.controller.settings.capture_paused ? "warning" : "normal", width: 104 }
            }, {
                id: "private", label: "Private", icon: "󰌾", shortcut: "",
                visible: !pane.controller.settings.capture_paused, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 104 }
            }, {
                id: "retention", label: pane.controller.settings.max_entries + " kept", icon: "󰓦", shortcut: "",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "normal", width: 112 }
            }, {
                id: "wipe", label: "Clear", icon: "󰆴", shortcut: "",
                visible: true, enabled: !pane.controller.actionInFlight,
                presentation: { group: "toolbar", tone: "danger", width: 94 }
            }]
            alignRight: false
            controlHeight: pane.toolbarHeight
            onTriggered: function (actionId) {
                if (actionId === "pause") pane.controller.toggleCapturePaused(false);
                else if (actionId === "private") pane.controller.toggleCapturePaused(true);
                else if (actionId === "retention") pane.controller.cycleRetention();
                else pane.controller.requestWipe();
            }
        }
    }
}
